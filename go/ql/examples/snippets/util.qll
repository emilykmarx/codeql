import go

/**
 * Util predicates
 */
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
