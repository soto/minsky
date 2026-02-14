"""Load and simulate the EndogenousMoney model — a multi-sector monetary model."""
import os
from pyminsky import minsky

EXAMPLES = os.path.join(os.path.dirname(__file__), "..", "examples")


def load_model():
    path = os.path.join(EXAMPLES, "EndogenousMoney.mky")
    minsky.load(path)


def test_load():
    load_model()
    n = len(minsky.model.items)
    assert n > 50, f"expected a complex model, got {n} items"
    print(f"Loaded EndogenousMoney: {n} items")


def test_monetary_variables_present():
    """Check that key monetary/financial variables exist."""
    load_model()

    keys = {k.split(":")[-1] for k in minsky.variableValues.keys()}
    expected = {"Loans", "Money", "Reserves", "GDP", "Int"}
    # Variable names use subscripts, so partial match
    for var in expected:
        found = any(var in k for k in keys)
        assert found, f"expected variable containing '{var}' not found in {keys}"
    print(f"All expected monetary variables present ({len(keys)} total)")


def test_initial_gdp():
    load_model()
    gdp = minsky.variableValues[":GDP"].value()
    assert gdp > 0, f"GDP should be positive at t=0, got {gdp}"
    print(f"Initial GDP = {gdp:.2f}")


def test_simulate():
    load_model()

    initial_gdp = minsky.variableValues[":GDP"].value()
    initial_loans = minsky.variableValues[":Loans"].value()

    minsky.nSteps(10)
    minsky.running(True)
    for _ in range(20):
        minsky.step()

    t = minsky.t()
    gdp = minsky.variableValues[":GDP"].value()
    loans = minsky.variableValues[":Loans"].value()
    money = minsky.variableValues[":Money"].value()

    assert t > 0, "simulation did not advance"
    assert gdp > 0, f"GDP went non-positive: {gdp}"
    assert money > 0, f"Money supply went non-positive: {money}"
    print(f"t={t:.2f}: GDP={gdp:.2f}, Loans={loans:.2f}, Money={money:.2f}")


def test_money_loans_relationship():
    """In endogenous money theory, money supply = deposits, which relates to loans."""
    load_model()

    minsky.nSteps(10)
    minsky.running(True)
    for _ in range(30):
        minsky.step()

    money = minsky.variableValues[":Money"].value()
    loans = minsky.variableValues[":Loans"].value()

    # Money should exceed loans (money = loans + reserves - equity + ...)
    assert money > loans, (
        f"money supply ({money:.2f}) should exceed loans ({loans:.2f})"
    )
    print(f"Money={money:.2f} > Loans={loans:.2f} (as expected)")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            print(f"  {name}...", end=" ")
            fn()
            print("OK")
    print("All EndogenousMoney tests passed.")
