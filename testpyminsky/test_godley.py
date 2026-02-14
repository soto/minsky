"""Load and simulate a Godley table model, verify accounting identities."""
import os
from pyminsky import minsky

DOC_DATA = os.path.join(os.path.dirname(__file__), "..", "doc", "data")


def load_monetary_model():
    path = os.path.join(DOC_DATA, "MonetaryModel01GodleyTable06Simulate01.mky")
    minsky.load(path)


def test_load():
    load_monetary_model()
    n = len(minsky.model.items)
    assert n > 0, "model has no items"
    print(f"Loaded MonetaryModel01: {n} items")


def test_godley_table_structure():
    """Find and inspect Godley table contents."""
    load_monetary_model()

    godley_found = False
    for i in range(len(minsky.model.items)):
        item = minsky.model.items[i]
        methods = item._list()
        # Godley icons have a .godleyIconCast method and .table accessor
        if ".godleyIconCast" not in methods:
            continue

        godley_found = True
        table = item.table
        rows, cols = table.rows(), table.cols()
        assert rows >= 2, f"Godley table too small: {rows} rows"
        assert cols >= 2, f"Godley table too small: {cols} cols"

        # Row 0 is header (stock names), Row 1 is initial conditions
        header = [table.cell(0, c) for c in range(cols)]
        assert "Reserves" in header
        assert "Loans" in header
        assert "Deposits" in header

        # Row 1 should be initial conditions
        ic_label = table.cell(1, 0)
        assert "Initial" in ic_label, f"expected initial conditions, got: {ic_label}"

        print(f"Godley table: {rows}r x {cols}c")
        print(f"  Stocks: {header[1:]}")
        for r in range(1, rows):
            flow = table.cell(r, 0)
            print(f"  Flow: {flow}")
        break

    assert godley_found, "no Godley table found in model"


def _balance_sheet():
    """Return (reserves, loans, deposits, equity) values."""
    reserves = minsky.variableValues[":Reserves"].value()
    loans = minsky.variableValues[":Loans"].value()
    deposits = minsky.variableValues[":Deposits"].value()
    # Equity key uses HTML subscript tags
    equity_key = [k for k in minsky.variableValues.keys() if k.startswith(":Banks")][0]
    equity = minsky.variableValues[equity_key].value()
    return reserves, loans, deposits, equity


def test_initial_balance_sheet():
    """Verify Assets = Liabilities + Equity at t=0."""
    load_monetary_model()

    reserves, loans, deposits, equity = _balance_sheet()
    assets = reserves + loans
    rhs = deposits + equity
    residual = abs(assets - rhs)

    assert residual < 1e-10, (
        f"balance sheet mismatch at t=0: "
        f"assets={assets} != deposits+equity={rhs}, residual={residual}"
    )
    print(f"t=0: Assets={assets:.2f} = Deposits={deposits:.2f} + Equity={equity:.2f}")


def test_accounting_identity_holds():
    """Run simulation and verify A = L + E at every checkpoint."""
    load_monetary_model()

    minsky.nSteps(10)
    minsky.running(True)

    max_residual = 0.0
    for epoch in range(10):
        for _ in range(10):
            minsky.step()

        reserves, loans, deposits, equity = _balance_sheet()
        assets = reserves + loans
        rhs = deposits + equity
        residual = abs(assets - rhs)
        max_residual = max(max_residual, residual)

        assert residual < 1e-8, (
            f"balance sheet violated at t={minsky.t():.2f}: "
            f"assets={assets:.6f} != {rhs:.6f}, residual={residual:.2e}"
        )

    t = minsky.t()
    print(f"Accounting identity held for 100 steps to t={t:.2f} "
          f"(max residual={max_residual:.2e})")


def test_equity_declines():
    """In this model bank spending exceeds interest income, so equity should decline."""
    load_monetary_model()

    _, _, _, initial_equity = _balance_sheet()

    minsky.nSteps(10)
    minsky.running(True)
    for _ in range(50):
        minsky.step()

    _, _, _, final_equity = _balance_sheet()
    assert final_equity < initial_equity, (
        f"equity should decline: initial={initial_equity:.4f}, final={final_equity:.4f}"
    )
    print(f"Equity declined: {initial_equity:.2f} -> {final_equity:.2f}")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            print(f"  {name}...", end=" ")
            fn()
            print("OK")
    print("All Godley tests passed.")
