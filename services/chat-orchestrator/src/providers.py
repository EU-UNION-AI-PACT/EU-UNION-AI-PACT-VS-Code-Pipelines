from __future__ import annotations
import os, json, httpx, asyncio
from typing import List, Dict, Any, AsyncGenerator, Tuple
from tenacity import retry, wait_exponential, stop_after_attempt

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_BASE = os.getenv("OPENAI_API_BASE","https://api.openai.com/v1")
OPENAI_MODEL = os.getenv("OPENAI_MODEL","gpt-4o-mini")

BEDROCK_MODEL = os.getenv("AWS_BEDROCK_MODEL")
LOCAL_TGI_URL = os.getenv("LOCAL_TGI_URL")
LOCAL_TGI_MODEL = os.getenv("LOCAL_TGI_MODEL")

TIMEOUT = 120

class ProviderManager:
    def __init__(self, order: List[str]):
        self.order = order

    def available(self)->List[str]:
        avail=[]
        if OPENAI_API_KEY: avail.append("openai")
        if BEDROCK_MODEL: avail.append("bedrock")
        if LOCAL_TGI_URL: avail.append("local")
        return [o for o in self.order if o in avail]

    @retry(wait=wait_exponential(min=1,max=8), stop=stop_after_attempt(3))
    async def generate(self, messages: List[Dict[str,str]], temperature: float, max_tokens:int, stream: bool=False):
        last_exc=None
        for p in self.available():
            try:
                if p=="openai":
                    return p, await self._openai_chat(messages, temperature, max_tokens)
                if p=="bedrock":
                    return p, await self._bedrock_chat(messages, temperature, max_tokens)
                if p=="local":
                    return p, await self._local_tgi(messages, temperature, max_tokens)
            except Exception as e:
                last_exc=e
                continue
        raise last_exc or RuntimeError("No provider succeeded")

    async def stream(self, messages: List[Dict[str,str]], temperature: float, max_tokens:int) -> AsyncGenerator[Tuple[str,str], None]:
        # Simple: attempt first available provider streaming (OpenAI if possible)
        for p in self.available():
            if p=="openai":
                async for ch in self._openai_stream(messages, temperature, max_tokens):
                    yield ("openai", ch)
                return
            if p=="local":
                async for ch in self._local_stream(messages, temperature, max_tokens):
                    yield ("local", ch)
                return
        # fallback non streaming
        p, full = await self.generate(messages, temperature, max_tokens, stream=False)
        yield (p, full)

    async def _openai_chat(self, messages, temperature, max_tokens):
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(f"{OPENAI_BASE}/chat/completions",
                                  headers={"Authorization":f"Bearer {OPENAI_API_KEY}"},
                                  json={"model":OPENAI_MODEL,"messages":messages,"temperature":temperature,"max_tokens":max_tokens})
            r.raise_for_status()
            js=r.json()
            return js["choices"][0]["message"]["content"]

    async def _openai_stream(self, messages, temperature, max_tokens):
        async with httpx.AsyncClient(timeout=None) as client:
            req = client.build_request("POST", f"{OPENAI_BASE}/chat/completions",
                headers={"Authorization":f"Bearer {OPENAI_API_KEY}"},
                json={"model":OPENAI_MODEL,"messages":messages,"temperature":temperature,"max_tokens":max_tokens,"stream":True})
            resp = await client.send(req, stream=True)
            async for line in resp.aiter_lines():
                if not line: continue
                if line.startswith("data: "):
                    payload=line[6:]
                    if payload=="[DONE]": break
                    try:
                        js=json.loads(payload)
                        delta=js["choices"][0]["delta"].get("content")
                        if delta:
                            yield delta
                    except:
                        continue

    async def _bedrock_chat(self, messages, temperature, max_tokens):
        # Real Bedrock implementation with Anthropic Claude
        try:
            import boto3
            import botocore.config
            
            region = os.getenv("AWS_REGION", "us-east-1")
            session = boto3.session.Session(region_name=region)
            bedrock = session.client("bedrock-runtime", 
                                   config=botocore.config.Config(retries={"max_attempts":3}))
            
            # Convert messages to Anthropic format
            prompt = self._messages_to_anthropic_prompt(messages)
            
            response = bedrock.invoke_model(
                modelId=BEDROCK_MODEL,
                contentType="application/json",
                accept="application/json",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "prompt": prompt
                })
            )
            
            body = json.loads(response["body"].read())
            return body["completion"]
            
        except ImportError:
            # Fallback if boto3 not available
            return f"[BEDROCK-FALLBACK] Response to: {messages[-1]['content'][:200]}"

    def _messages_to_anthropic_prompt(self, messages: List[dict]) -> str:
        """Convert OpenAI format messages to Anthropic prompt format"""
        convo = []
        system = []
        
        for m in messages:
            if m["role"] == "system":
                system.append(m["content"])
            else:
                role = "Human" if m["role"] == "user" else "Assistant"
                convo.append(f"\n\n{role}: {m['content']}")
        
        system_text = " ".join(system) if system else ""
        conversation = "".join(convo)
        
        return f"{system_text}{conversation}\n\nAssistant:"

    async def _local_tgi(self, messages, temperature, max_tokens):
        if not LOCAL_TGI_URL:
            raise RuntimeError("LOCAL_TGI_URL missing")
        prompt = self._flatten(messages)
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(f"{LOCAL_TGI_URL}/generate",
                                  json={"inputs":prompt,"parameters":{"temperature":temperature,"max_new_tokens":max_tokens}})
            r.raise_for_status()
            js=r.json()
            if isinstance(js, list):
                return js[0]["generated_text"]
            return js["generated_text"]

    async def _local_stream(self, messages, temperature, max_tokens):
        # Depending on TGI server; simplified stub (non-stream)
        full = await self._local_tgi(messages, temperature, max_tokens)
        yield full

    def _flatten(self, messages):
        return "\n".join([f"{m['role'].upper()}: {m['content']}" for m in messages])
