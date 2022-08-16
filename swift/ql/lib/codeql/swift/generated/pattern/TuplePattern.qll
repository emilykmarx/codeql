// generated by codegen/codegen.py
private import codeql.swift.generated.Synth
private import codeql.swift.generated.Raw
import codeql.swift.elements.pattern.Pattern

class TuplePatternBase extends Synth::TTuplePattern, Pattern {
  override string getAPrimaryQlClass() { result = "TuplePattern" }

  Pattern getImmediateElement(int index) {
    result =
      Synth::convertPatternFromRaw(Synth::convertTuplePatternToRaw(this)
            .(Raw::TuplePattern)
            .getElement(index))
  }

  final Pattern getElement(int index) { result = getImmediateElement(index).resolve() }

  final Pattern getAnElement() { result = getElement(_) }

  final int getNumberOfElements() { result = count(getAnElement()) }
}
