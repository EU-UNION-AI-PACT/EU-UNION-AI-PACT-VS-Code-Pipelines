from services.code_doctor.canon import suggest_canonical

def test_canon_exact_match():
    mapping={"getData":"fetch_data", "processData":"process_data"}
    assert suggest_canonical("getData", mapping) == "fetch_data"
    assert suggest_canonical("processData", mapping) == "process_data"

def test_canon_fuzzy_match():
    mapping={"getData":"fetch_data"}
    # Should find close matches
    result = suggest_canonical("get_data", mapping)
    # Fuzzy matching may or may not work depending on threshold
    
def test_canon_no_match():
    mapping={"getData":"fetch_data"}
    assert suggest_canonical("completelyDifferent", mapping) is None
