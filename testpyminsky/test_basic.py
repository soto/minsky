"""Basic pyminsky import and version check."""
from pyminsky import minsky

def test_import():
    assert minsky is not None

def test_version():
    version = minsky.minskyVersion()
    assert version
    parts = version.split(".")
    assert len(parts) >= 2, f"unexpected version format: {version}"
    print(f"Minsky version: {version}")

def test_enums():
    import pyminsky
    assert isinstance(pyminsky.enum, dict)
    assert "::minsky::OperationType::Type" in pyminsky.enum
    op_types = pyminsky.enum["::minsky::OperationType::Type"]
    assert "add" in op_types
    assert "multiply" in op_types
    assert "integrate" in op_types
    print(f"Operation types: {len(op_types)} defined")

def test_introspection():
    methods = minsky._list()
    assert len(methods) > 0
    # Check some essential methods exist
    essential = [".load", ".save", ".step", ".t", ".running", ".nSteps"]
    for m in essential:
        assert m in methods, f"missing method: {m}"
    print(f"Minsky API: {len(methods)} methods/attributes")

if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            print(f"  {name}...", end=" ")
            fn()
            print("OK")
    print("All basic tests passed.")
