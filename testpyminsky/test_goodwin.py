"""Load and simulate the Goodwin growth cycle model."""
import os
from pyminsky import minsky

EXAMPLES = os.path.join(os.path.dirname(__file__), "..", "examples")


def test_load_goodwin():
    path = os.path.join(EXAMPLES, "GoodwinLinear02.mky")
    minsky.load(path)
    assert minsky.t() == 0.0
    print(f"Loaded GoodwinLinear02.mky")


def test_variables():
    path = os.path.join(EXAMPLES, "GoodwinLinear02.mky")
    minsky.load(path)

    keys = list(minsky.variableValues.keys())
    assert len(keys) > 0

    expected_vars = {"Investment", "K", "L", "Y", "Profit"}
    found = {k.split(":")[-1] for k in keys}
    missing = expected_vars - found
    assert not missing, f"missing variables: {missing}"
    print(f"Variables ({len(keys)}): {sorted(found)}")


def test_simulate():
    path = os.path.join(EXAMPLES, "GoodwinLinear02.mky")
    minsky.load(path)

    minsky.nSteps(10)
    minsky.running(True)

    times = []
    for _ in range(5):
        minsky.step()
        times.append(minsky.t())

    assert times[-1] > 0, "simulation did not advance"
    assert times == sorted(times), "time is not monotonically increasing"

    # Check that variables evolved
    y_val = minsky.variableValues[":Y"].value()
    assert y_val > 0, f"Y should be positive, got {y_val}"
    print(f"Simulated to t={times[-1]:.4f}, Y={y_val:.4f}")


def test_variable_values_change():
    """Verify the simulation actually changes variable values."""
    path = os.path.join(EXAMPLES, "GoodwinLinear02.mky")
    minsky.load(path)

    initial = {}
    for k in minsky.variableValues.keys():
        initial[k] = minsky.variableValues[k].value()

    minsky.nSteps(10)
    minsky.running(True)
    for _ in range(10):
        minsky.step()

    changed = 0
    for k in minsky.variableValues.keys():
        if k.startswith("constant:"):
            continue
        val = minsky.variableValues[k].value()
        if abs(val - initial.get(k, 0)) > 1e-10:
            changed += 1

    assert changed > 0, "no variables changed during simulation"
    print(f"{changed} variables changed after simulation")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            print(f"  {name}...", end=" ")
            fn()
            print("OK")
    print("All Goodwin tests passed.")
