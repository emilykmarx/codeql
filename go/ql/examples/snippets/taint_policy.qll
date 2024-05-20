import go

/* Logic for path queries */
bindingset[pathRegex]
predicate nodeInFile(DataFlow::Node node, string pathRegex) {
  node.getFile().getAbsolutePath().matches("%" + pathRegex + "%")
}

bindingset[sourceVar]
predicate ssa(DataFlow::Node node, string sourceVar) {
  node.(DataFlow::SsaNode).getSourceVariable().getName() = sourceVar
}

// Doesn't seem to work for SSA nodes that are recvrs -- not sure if getEnclosingCallable() does
string getNodeFct(DataFlow::Node node) {
  result = node.getRoot().getEnclosingFunction().getName()
}

bindingset[file]
predicate nodeOnLine(DataFlow::Node node, string file, int line) {
  nodeInFile(node, file) and
  node.getStartLine() = line
}

// Read of variable whose watchpoint was hit
class WatchedVar extends DataFlow::Node {
  WatchedVar() {
    this instanceof DataFlow::ReadNode
    and this.asExpr().toString() = "XXX_VAR"
    // and nodeOnLine(this, "XXX_FILE", -1) and
  }

}

// Variables tainted by watched variable read
class TaintedVar extends DataFlow::Node {
  TaintedVar() {
    any()
    //nodeOnLine(this, "XXX_FILE", -1) and
  }
}
