import go
import util

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    exists(Field f, Write w |
      f.hasQualifiedName("command-line-arguments", "dnsConfig", "search") and
      w.writesField(_, f, source)
    )
  }

  predicate isSink(DataFlow::Node sink) {
    exists(Function f | f.hasQualifiedName("net", "dnsPacketRoundTrip")
      and sink = f.getACall().getArgument(3))
  }
}
module Flow = TaintTracking::Global<Config>;
import Flow::PathGraph

/*
from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink)
select source, sink
*/

// PARTIAL QUERIES
int explorationLimit() { result = 5000 }
module MyPartialFlowFwd = Flow::FlowExplorationFwd<explorationLimit/0>;
module MyPartialFlowRev = Flow::FlowExplorationRev<explorationLimit/0>;

predicate adhocPartialFlowFwd(Callable c, MyPartialFlowFwd::PartialPathNode n, DataFlow::Node src, int dist) {
  exists(MyPartialFlowFwd::PartialPathNode source |
    MyPartialFlowFwd::partialFlow(source, n, dist) and
    src = source.getNode() and
    c = n.getNode().getEnclosingCallable()
  )
}

predicate adhocPartialFlowRev(Callable c, MyPartialFlowRev::PartialPathNode n, DataFlow::Node snk, int dist) {
  exists(MyPartialFlowRev::PartialPathNode sink |
    MyPartialFlowRev::partialFlow(n, sink, dist) and // note different param order for reverse
    snk = sink.getNode() and
    c = n.getNode().getEnclosingCallable()
  )
}

from Callable c, MyPartialFlowFwd::PartialPathNode n, DataFlow::Node src, int dist
where Config::isSource(src)
and adhocPartialFlowFwd(c, n, src, dist)
select src, n, c, n.getNode().getStartLine() as line order by line

/*
from Callable c, MyPartialFlowRev::PartialPathNode n, DataFlow::Node snk, int dist
where Config::isSink(snk)
and adhocPartialFlowRev(c, n, snk, dist)
select n, snk, c, n.getNode().getStartLine() as line order by line
*/
