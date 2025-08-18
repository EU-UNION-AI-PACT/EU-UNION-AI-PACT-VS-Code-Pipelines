from services.data_hub.src.fusion import fuse_results

def test_fuse_basic():
    """Test basic fusion functionality"""
    docs=[
        {"id":"1","title":"A Climate Data","description":"temp","score":0.1,"source":"s1","kind":"dataset"},
        {"id":"2","title":"B Climate","description":"precip","score":0.2,"source":"s1","kind":"dataset"},
        {"id":"1","title":"A Climate Data","description":"temp","score":0.1,"source":"s2","kind":"dataset"},  # duplicate
    ]
    fused = fuse_results("climate", docs, limit=2)
    assert len(fused) == 2
    assert fused[0]["id"] != fused[1]["id"]  # No duplicates

def test_fuse_scoring():
    """Test that scoring works correctly"""
    docs=[
        {"id":"1","title":"Climate Change","description":"Global warming data","score":0.0,"source":"s1","kind":"dataset"},
        {"id":"2","title":"Weather","description":"Local temperature","score":0.0,"source":"s1","kind":"dataset"},
    ]
    fused = fuse_results("climate", docs, limit=2)
    # First doc should score higher due to "climate" match
    assert "climate" in fused[0]["title"].lower() or "climate" in fused[0]["description"].lower()
