// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.expr.Expr

class KeyPathApplicationExprBase extends Synth::TKeyPathApplicationExpr, Expr {
  override string getAPrimaryQlClass() { result = "KeyPathApplicationExpr" }

  Expr getImmediateBase() {
    result =
      Synth::convertExprFromRaw(Synth::convertKeyPathApplicationExprToRaw(this)
            .(Raw::KeyPathApplicationExpr)
            .getBase())
  }

  final Expr getBase() { result = getImmediateBase().resolve() }

  Expr getImmediateKeyPath() {
    result =
      Synth::convertExprFromRaw(Synth::convertKeyPathApplicationExprToRaw(this)
            .(Raw::KeyPathApplicationExpr)
            .getKeyPath())
  }

  final Expr getKeyPath() { result = getImmediateKeyPath().resolve() }
}
