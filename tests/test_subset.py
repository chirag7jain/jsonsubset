import json
from fixtures import gen_expr
import tests.reference_implementation
import subset

from hypothesis import given
from tests.hypothesis_strategies import JSON_FULL_LITE

TEST_CASES = [
    {},
    1,
    "123",
    "ábçdé",
    4129830912830,
    {"id": 1},
    {'/': None},
    {"id": "123"},
    {"id": "ábçdé"},
    {"a": {"nested": "value"}},
    {"a": {"nested": 1234}},
    {"a": {"more": {"complex": "json"}}, "with": {"branches": {"like": "this_one", "and": "that_one"}}}
]

def test_predefined_cases(gen_expr):
    for test_case in TEST_CASES:
        test_case_bytes = json.dumps(test_case).encode("utf-8")

        for expr in gen_expr(test_case):
            reference = tests.reference_implementation.subset(expr, test_case_bytes)
            actual = subset.JsonSubset(expr).parse(test_case_bytes)

            assert reference == actual

@given(JSON_FULL_LITE)
def test_random_cases(gen_expr, test_case):
    test_case_bytes = json.dumps(test_case).encode("utf-8")

    for expr in gen_expr(test_case):
        reference = tests.reference_implementation.subset(expr, test_case_bytes)
        actual = subset.JsonSubset(expr).parse(test_case_bytes)

        assert reference == actual
