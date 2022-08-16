// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.expr.ApplyExpr
import codeql.swift.elements.expr.Expr

class SelfApplyExprBase extends Synth::TSelfApplyExpr, ApplyExpr {
  Expr getImmediateBaseExpr() {
    result =
      Synth::convertExprFromRaw(Synth::convertSelfApplyExprToRaw(this)
            .(Raw::SelfApplyExpr)
            .getBaseExpr())
  }

  final Expr getBaseExpr() { result = getImmediateBaseExpr().resolve() }
}
