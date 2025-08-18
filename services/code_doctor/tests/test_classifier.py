from services.code_doctor.classifier import classify_issue

def test_missing_symbol_detect():
    log="Traceback (most recent call last):\n  File \"test.py\", line 5, in <module>\n    result = getData()\nNameError: name 'getData' is not defined"
    issues=classify_issue(log, None)
    assert len(issues) > 0
    assert any(i["symbol"]=="getData" for i in issues)
    assert any(i["type"]=="missing_symbol" for i in issues)

def test_attribute_error_detect():
    log="AttributeError: 'NoneType' object has no attribute 'process'"
    issues=classify_issue(log, None)
    assert len(issues) > 0
    
def test_lint_report_processing():
    lint_report = {
        "messages": [
            {"ruleId": "no-undef", "message": "'undefinedVar' is not defined"}
        ]
    }
    issues = classify_issue("", lint_report)
    assert len(issues) > 0
