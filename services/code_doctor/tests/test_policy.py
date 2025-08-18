from services.code_doctor.policy import can_auto_apply, requires_review

def test_safe_actions_auto_apply():
    actions = ["rename:getData->fetch_data", "final_newline"]
    assert can_auto_apply("medium", actions) == True
    assert requires_review(actions, "medium") == False

def test_risky_actions_block_auto_apply():
    actions = ["llm_repair", "rename:getData->fetch_data"]
    assert can_auto_apply("medium", actions) == False
    assert requires_review(actions, "medium") == True

def test_high_risk_level_requires_review():
    actions = ["rename:getData->fetch_data"]
    assert requires_review(actions, "high") == True

def test_low_risk_level_allows_auto():
    actions = ["rename:getData->fetch_data", "final_newline"]
    assert can_auto_apply("low", actions) == True
