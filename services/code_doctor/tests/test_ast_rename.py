from services.code_doctor.ast_rewriters import apply_rewriters

def test_rename_python():
    code="def getData():\n    return 1\n\nx = getData()\nprint(x)\n"
    new, acts = apply_rewriters("python", code, {"getData":"fetch_data"}, {"python_basic":{}})
    assert "fetch_data()" in new
    assert "def fetch_data():" in new
    assert any(a.startswith("rename:") for a in acts)
    assert "final_newline" in acts

def test_rename_javascript():
    code="function getData() { return 1; }\nlet x = getData();"
    new, acts = apply_rewriters("javascript", code, {"getData":"fetchData"}, {})
    assert "fetchData()" in new
    assert "function fetchData()" in new
    assert any(a.startswith("rename:") for a in acts)

def test_no_changes():
    code="def fetch_data():\n    return 1\n"
    new, acts = apply_rewriters("python", code, {"getData":"fetch_data"}, {})
    assert new == code
    assert len(acts) == 0
