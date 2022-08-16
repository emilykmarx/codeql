// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.expr.Expr

class TupleElementExprBase extends Synth::TTupleElementExpr, Expr {
  override string getAPrimaryQlClass() { result = "TupleElementExpr" }

  Expr getImmediateSubExpr() {
    result =
      Synth::convertExprFromRaw(Synth::convertTupleElementExprToRaw(this)
            .(Raw::TupleElementExpr)
            .getSubExpr())
  }

  final Expr getSubExpr() { result = getImmediateSubExpr().resolve() }

  int getIndex() {
    result = Synth::convertTupleElementExprToRaw(this).(Raw::TupleElementExpr).getIndex()
  }
}
