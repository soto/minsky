"""Smoke test: load every .mky example file and verify it parses."""
import os
from pyminsky import minsky

EXAMPLES = os.path.join(os.path.dirname(__file__), "..", "examples")


def test_load_all_examples():
    mky_files = sorted(f for f in os.listdir(EXAMPLES) if f.endswith(".mky"))
    assert len(mky_files) > 0, "no .mky files found"

    passed = 0
    failed = []
    for f in mky_files:
        path = os.path.join(EXAMPLES, f)
        try:
            minsky.load(path)
            n_vars = len(minsky.variableValues)
            n_items = len(minsky.model.items)
            assert n_vars > 0, "no variables"
            print(f"  {f:50s} {n_items:4d} items, {n_vars:3d} vars")
            passed += 1
        except Exception as e:
            failed.append((f, str(e)))
            print(f"  {f:50s} FAILED: {e}")

    print(f"\n{passed}/{len(mky_files)} examples loaded successfully")
    if failed:
        print(f"Failures:")
        for f, e in failed:
            print(f"  {f}: {e}")
    assert not failed, f"{len(failed)} example(s) failed to load"


def test_all_examples_simulate():
    """Load each example and run a few simulation steps."""
    mky_files = sorted(f for f in os.listdir(EXAMPLES) if f.endswith(".mky"))

    passed = 0
    failed = []
    for f in mky_files:
        path = os.path.join(EXAMPLES, f)
        try:
            minsky.load(path)
            minsky.nSteps(5)
            minsky.running(True)
            for _ in range(3):
                minsky.step()
            t = minsky.t()
            assert t > 0, f"time did not advance (t={t})"
            print(f"  {f:50s} t={t:.4f}")
            passed += 1
        except Exception as e:
            failed.append((f, str(e)))
            print(f"  {f:50s} FAILED: {e}")

    print(f"\n{passed}/{len(mky_files)} examples simulated successfully")
    if failed:
        print(f"Failures:")
        for f, e in failed:
            print(f"  {f}: {e}")


if __name__ == "__main__":
    print("=== Loading all examples ===")
    test_load_all_examples()
    print()
    print("=== Simulating all examples ===")
    test_all_examples_simulate()
