// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.expr.Expr

class ExplicitCastExprBase extends Synth::TExplicitCastExpr, Expr {
  Expr getImmediateSubExpr() {
    result =
      Synth::convertExprFromRaw(Synth::convertExplicitCastExprToRaw(this)
            .(Raw::ExplicitCastExpr)
            .getSubExpr())
  }

  final Expr getSubExpr() { result = getImmediateSubExpr().resolve() }
}
