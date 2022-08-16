// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.AstNode
import codeql.swift.elements.type.Type

class TypeReprBase extends Synth::TTypeRepr, AstNode {
  override string getAPrimaryQlClass() { result = "TypeRepr" }

  Type getImmediateType() {
    result = Synth::convertTypeFromRaw(Synth::convertTypeReprToRaw(this).(Raw::TypeRepr).getType())
  }

  final Type getType() { result = getImmediateType().resolve() }

  final predicate hasType() { exists(getType()) }
}
