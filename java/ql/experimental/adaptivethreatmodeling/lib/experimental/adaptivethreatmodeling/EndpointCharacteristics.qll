/**
 * For internal use only.
 */

private import java as java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.security.QueryInjection
import semmle.code.java.security.PathCreation
import semmle.code.java.security.RequestForgery
private import semmle.code.java.dataflow.ExternalFlow
private import semmle.code.java.dataflow.internal.FlowSummaryImpl as FlowSummaryImpl
import experimental.adaptivethreatmodeling.EndpointTypes
private import experimental.adaptivethreatmodeling.ATMConfig
private import semmle.code.java.security.ExternalAPIs as ExternalAPIs
private import semmle.code.java.Expr as Expr

/*
 * Predicates that are used to surface prompt examples and candidates for classification with an ML model.
 */

/**
 * Holds if `sink` is a known sink of type `sinkType`.
 */
predicate isKnownSink(DataFlow::Node sink, SinkType sinkType) {
  // If the list of characteristics includes positive indicators with maximal confidence for this class, then it's a
  // known sink for the class.
  sinkType != any(NegativeSinkType negative) and
  exists(EndpointCharacteristics::EndpointCharacteristic characteristic |
    characteristic.appliesToEndpoint(sink) and
    characteristic.hasImplications(sinkType, true, characteristic.maximalConfidence())
  )
}

/**
 * Holds if the given endpoint has a self-contradictory combination of characteristics. Detects errors in our endpoint
 * characteristics. Lists the problematic characterisitics and their implications for all such endpoints, together with
 * an error message indicating why this combination is problematic.
 *
 * Copied from javascript/ql/experimental/adaptivethreatmodeling/test/endpoint_large_scale/ContradictoryEndpointCharacteristics.ql
 */
predicate erroneousEndpoints(
  DataFlow::Node endpoint, EndpointCharacteristic characteristic, EndpointType endpointClass,
  float confidence, string errorMessage
) {
  // An endpoint's characteristics should not include positive indicators with medium/high confidence for more than one
  // class.
  exists(EndpointCharacteristic characteristic2, EndpointType endpointClass2, float confidence2 |
    endpointClass != endpointClass2 and
    characteristic.appliesToEndpoint(endpoint) and
    characteristic2.appliesToEndpoint(endpoint) and
    characteristic.hasImplications(endpointClass, true, confidence) and
    characteristic2.hasImplications(endpointClass2, true, confidence2) and
    confidence > characteristic.mediumConfidence() and
    confidence2 > characteristic2.mediumConfidence() and
    // It's valid for a node to satisfy the logic for both `isSink` and `isSanitizer`, but in that case it will be
    // treated by the actual query as a sanitizer, since the final logic is something like
    // `isSink(n) and not isSanitizer(n)`.
    not (
      characteristic instanceof IsSanitizerCharacteristic or
      characteristic2 instanceof IsSanitizerCharacteristic
    )
    // and
    // // We currently know of some sink types that overlap with one another.
    // not knownOverlappingCharacteristics(characteristic, characteristic2)
  ) and
  errorMessage = "Endpoint has high-confidence positive indicators for multiple classes"
  or
  // An enpoint's characteristics should not include positive indicators with medium/high confidence for some class and
  // also include negative indicators with medium/high confidence for this same class.
  exists(EndpointCharacteristic characteristic2, float confidence2 |
    characteristic.appliesToEndpoint(endpoint) and
    characteristic2.appliesToEndpoint(endpoint) and
    characteristic.hasImplications(endpointClass, true, confidence) and
    characteristic2.hasImplications(endpointClass, false, confidence2) and
    confidence > characteristic.mediumConfidence() and
    confidence2 > characteristic2.mediumConfidence()
  ) and
  errorMessage = "Endpoint has high-confidence positive and negative indicators for the same class"
}

predicate erroneousConfidences(
  EndpointCharacteristic characteristic, float confidence, string errorMessage
) {
  characteristic.hasImplications(_, _, confidence) and
  (confidence < 0 or confidence > 1) and
  errorMessage = "Characteristic has an indicator with confidence outside of [0, 1]"
}

// /**
//  * Holds if `characteristic1` and `characteristic2` are among the pairs of currently known positive characteristics that
//  * have some overlap in their known sinks (always for the same query type). This is not necessarily a problem, because
//  * both characteristics belong to the same query.
//  */
// private predicate knownOverlappingCharacteristics(
//   EndpointCharacteristics::EndpointCharacteristic characteristic1,
//   EndpointCharacteristics::EndpointCharacteristic characteristic2
// ) {
//   characteristic1 != characteristic2 and
//   characteristic1 = ["file creation sink", "other path injection sink"] and
//   characteristic2 = ["file creation sink", "other path injection sink"]
// }
predicate isTypeAccess(DataFlow::Node n) { n.asExpr() instanceof TypeAccess }

/**
 * Holds if `n` has the given metadata.
 *
 * This is a helper function to extract and export needed information about each endpoint in the sink candidate query as
 * well as the queries that exatract positive and negative examples for the prompt / training set. The metadata is
 * extracted as a string in the format of a Python dictionary.
 */
predicate hasMetadata(DataFlow::Node n, string metadata) {
  exists(
    Callable callee, Call call, string package, string type, boolean subtypes, string name,
    string signature, string ext, int input, string provenance, boolean isPublic,
    boolean isExternalApiDataNode
  |
    n.asExpr() = call.getArgument(input) and
    callee = call.getCallee() and
    package = callee.getDeclaringType().getPackage().getName() and
    type = callee.getDeclaringType().getName() and //TODO: Will this work for inner classes? Will it produce X$Y? What about lambdas? What about enums? What about interfaces? What about annotations?
    (
      if callee.isFinal() or callee.getDeclaringType().isFinal()
      then subtypes = false // See https://github.com/github/codeql-java-team/issues/254#issuecomment-1422296423
      else subtypes = true
    ) and
    name = callee.getName() and // TODO: Will this work for constructors?
    signature = paramsString(callee) and // TODO: Why are brackets being escaped (`\[\]` vs `[]`)?
    ext = "" and // see https://github.slack.com/archives/CP9127VUK/p1673979477496069
    provenance = "ai-generated" and
    (if callee.isPublic() then isPublic = true else isPublic = false) and
    (
      if n instanceof ExternalAPIs::ExternalApiDataNode
      then isExternalApiDataNode = true
      else isExternalApiDataNode = false
    ) and
    metadata =
      "{'Package': '" + package + "', 'Type': '" + type + "', 'Subtypes': " + subtypes +
        ", 'Name': '" + name + "', 'Signature': '" + signature + "', 'Ext': '" + ext +
        "', 'Argument index': " + input + ", 'Provenance': '" + provenance + "', 'Is public': " +
        isPublic + ", 'Is passed to external API': " + isExternalApiDataNode + "}" // TODO: Why are the curly braces added twice?
  )
}

/*
 * EndpointCharacteristic classes.
 */

/**
 * A set of characteristics that a particular endpoint might have. This set of characteristics is used to make decisions
 * about whether to include the endpoint in the training set and with what label, as well as whether to score the
 * endpoint at inference time.
 */
abstract class EndpointCharacteristic extends string {
  /**
   * Holds when the string matches the name of the characteristic, which should describe some characteristic of the
   * endpoint that is meaningful for determining whether it's a sink and if so of which type
   */
  bindingset[this]
  EndpointCharacteristic() { any() }

  /**
   * Holds for endpoints that have this characteristic. This predicate contains the logic that applies characteristics
   * to the appropriate set of dataflow nodes.
   */
  abstract predicate appliesToEndpoint(DataFlow::Node n);

  /**
   * This predicate describes what the characteristic tells us about an endpoint.
   *
   * Params:
   * endpointClass: The sink type.
   * isPositiveIndicator: If true, this characteristic indicates that this endpoint _is_ a member of the class; if
   * false, it indicates that it _isn't_ a member of the class.
   * confidence: A float in [0, 1], which tells us how strong an indicator this characteristic is for the endpoint
   * belonging / not belonging to the given class. A confidence near zero means this characteristic is a very weak
   * indicator of whether or not the endpoint belongs to the class. A confidence of 1 means that all endpoints with
   * this characteristic definitively do/don't belong to the class.
   */
  abstract predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  );

  /** Indicators with confidence at or above this threshold are considered to be high-confidence indicators. */
  final float getHighConfidenceThreshold() { result = 0.8 }

  // The following are some confidence values that are used in practice by the subclasses. They are defined as named
  // constants here to make it easier to change them in the future.
  final float maximalConfidence() { result = 1.0 }

  final float highConfidence() { result = 0.9 }

  final float mediumConfidence() { result = 0.6 }
}

/**
 * Endpoints identified as "create-file" sinks by the MaD modeling are tainted path sinks with maximal confidence.
 */
private class CreateFileSinkCharacteristic extends EndpointCharacteristic {
  CreateFileSinkCharacteristic() { this = "create file" }

  override predicate appliesToEndpoint(DataFlow::Node n) { sinkNode(n, "create-file") }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof TaintedPathSinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "PathCreation" by the standard Java libraries are path injection sinks with maximal
 * confidence.
 */
private class CreatePathSinkCharacteristic extends EndpointCharacteristic {
  CreatePathSinkCharacteristic() { this = "create path" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    n.asExpr() = any(PathCreation p).getAnInput()
  }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof TaintedPathSinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "sql" sinks by the MaD modeling are SQL sinks with maximal confidence.
 */
private class SqlMaDSinkCharacteristic extends EndpointCharacteristic {
  SqlMaDSinkCharacteristic() { this = "mad modeled sql" }

  override predicate appliesToEndpoint(DataFlow::Node n) { sinkNode(n, "sql") }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof SqlSinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "SqlInjectionSink" by the standard Java libraries are SQL injection sinks with maximal
 * confidence.
 */
private class SqlInjectionSinkCharacteristic extends EndpointCharacteristic {
  SqlInjectionSinkCharacteristic() { this = "other modeled sql" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    n instanceof QueryInjectionSink and
    not sinkNode(n, "sql")
  }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof SqlSinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "open-url" sinks by the MaD modeling are SSRF sinks with maximal confidence.
 */
private class UrlOpenSinkCharacteristic extends EndpointCharacteristic {
  UrlOpenSinkCharacteristic() { this = "open url" }

  override predicate appliesToEndpoint(DataFlow::Node n) { sinkNode(n, "open-url") }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof RequestForgerySinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "jdbc-url" sinks by the MaD modeling are SSRF sinks with maximal confidence.
 */
private class JdbcUrlSinkCharacteristic extends EndpointCharacteristic {
  JdbcUrlSinkCharacteristic() { this = "jdbc url" }

  override predicate appliesToEndpoint(DataFlow::Node n) { sinkNode(n, "jdbc-url") }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof RequestForgerySinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/**
 * Endpoints identified as "RequestForgerySink" by the standard Java libraries but not by MaD models are SSRF sinks with
 * maximal confidence.
 */
private class RequestForgeryOtherSinkCharacteristic extends EndpointCharacteristic {
  RequestForgeryOtherSinkCharacteristic() { this = "request forgery" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    n instanceof RequestForgerySink and
    not sinkNode(n, "open-url") and
    not sinkNode(n, "jdbc-url")
  }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof RequestForgerySinkType and
    isPositiveIndicator = true and
    confidence = maximalConfidence()
  }
}

/*
 * Characteristics that are indicative of not being a sink of any type, and have historically been used to select
 * negative samples for training.
 */

/**
 * A characteristic that is an indicator of not being a sink of any type, because it's a modeled argument.
 */
abstract class OtherModeledArgumentCharacteristic extends EndpointCharacteristic {
  bindingset[this]
  OtherModeledArgumentCharacteristic() { any() }
}

/**
 * A characteristic that is an indicator of not being a sink of any type, because it's an argument to a function of a
 * builtin object.
 */
abstract private class ArgumentToBuiltinFunctionCharacteristic extends OtherModeledArgumentCharacteristic {
  bindingset[this]
  ArgumentToBuiltinFunctionCharacteristic() { any() }
}

/**
 * A high-confidence characteristic that indicates that an endpoint is not a sink of any type.
 */
abstract private class NotASinkCharacteristic extends EndpointCharacteristic {
  bindingset[this]
  NotASinkCharacteristic() { any() }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof NegativeSinkType and
    isPositiveIndicator = true and
    confidence = highConfidence()
  }
}

/**
 * A medium-confidence characteristic that indicates that an endpoint is not a sink of any type.
 *
 * TODO: This class is currently not private, because the current extraction logic explicitly avoids including these
 * endpoints in the training data. We might want to change this in the future.
 */
abstract class LikelyNotASinkCharacteristic extends EndpointCharacteristic {
  bindingset[this]
  LikelyNotASinkCharacteristic() { any() }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof NegativeSinkType and
    isPositiveIndicator = true and
    confidence = mediumConfidence()
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is a type access. Type accesses are not sinks.
 */
private class IsTypeAccessCharacteristic extends NotASinkCharacteristic {
  IsTypeAccessCharacteristic() { this = "type access" }

  override predicate appliesToEndpoint(DataFlow::Node n) { isTypeAccess(n) }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is a sanitizer for some sink type. A sanitizer can
 * never be a sink.
 */
private class IsSanitizerCharacteristic extends NotASinkCharacteristic {
  IsSanitizerCharacteristic() { this = "sanitizer" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    exists(TaintTracking::Configuration config | config.isSanitizer(n))
  }
}

// /**
//  * An EndpointFilterCharacteristic that indicates that an endpoint is a MaD taint step. MaD modeled taint steps are
//  * global, so they are not sinks for any query. Non-MaD taint steps might be specific to a particular query, so we don't
//  * filter those out.
//  */
// private class IsMaDTaintStepCharacteristic extends NotASinkCharacteristic {
//   IsMaDTaintStepCharacteristic() { this = "mad taint step" }
//   override predicate appliesToEndpoint(DataFlow::Node n) {
//     FlowSummaryImpl::Private::Steps::summaryThroughStepValue(n, _, _)
//     or
//     // FlowSummaryImpl::Private::Steps::summaryThroughStepTaint(n, _, _) or
//     // FlowSummaryImpl::Private::Steps::summaryGetterStep(n, _, _, _) or
//     FlowSummaryImpl::Private::Steps::summarySetterStep(n, _, _, _)
//   }
// }
/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is an argument to a safe external API method.
 *
 * Based on java/ql/lib/semmle/code/java/security/ExternalAPIs.qll.
 *
 * TODO: Is this correct?
 */
private class SafeExternalApiMethodCharacteristic extends NotASinkCharacteristic {
  string baseDescription;

  SafeExternalApiMethodCharacteristic() {
    baseDescription = "safe external API method " and
    this = any(string s | s = baseDescription + ["org.junit", "other than org.junit"])
  }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    exists(Expr::Call call |
      n.asExpr() = call.getAnArgument() and
      call.getCallee() instanceof ExternalAPIs::SafeExternalApiMethod and
      (
        // The vast majority of calls to safe external API methods involve junit. To get a diverse set of negative
        // examples, we break those off into a separate characteristic.
        call.getCallee().getDeclaringType().getPackage().getName().matches("org.junit%") and
        this = baseDescription + "org.junit"
        or
        not call.getCallee().getDeclaringType().getPackage().getName().matches("org.junit%") and
        this = baseDescription + "other than org.junit"
      )
    )
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is an argument to an exception, which is not a sink.
 */
private class ExceptionCharacteristic extends NotASinkCharacteristic {
  ExceptionCharacteristic() { this = "exception" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    exists(Expr::Call call, RefType type |
      n.asExpr() = call.getAnArgument() and
      type = call.getCallee().getDeclaringType().getASupertype*() and
      type instanceof TypeThrowable
    )
  }
}

/*
 * Characteristics that have historically acted as endpoint filters to exclude endpoints from scoring at inference time.
 */

/** A characteristic that has historically acted as an endpoint filter for inference-time scoring. */
abstract class EndpointFilterCharacteristic extends EndpointCharacteristic {
  bindingset[this]
  EndpointFilterCharacteristic() { any() }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is unlikely to be a sink of any type.
 */
abstract private class StandardEndpointFilterCharacteristic extends EndpointFilterCharacteristic {
  bindingset[this]
  StandardEndpointFilterCharacteristic() { any() }

  override predicate hasImplications(
    EndpointType endpointClass, boolean isPositiveIndicator, float confidence
  ) {
    endpointClass instanceof NegativeSinkType and
    isPositiveIndicator = true and
    confidence = mediumConfidence()
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is a constant expression. While a constant expression
 * can be a sink, it cannot be part of a tainted flow: Constant expressions always evaluate to a constant primitive
 * value, so they can't ever appear in an alert. These endpoints are therefore excluded from scoring at inference time.
 *
 * WARNING: These endpoints should not be used as negative samples for training, because they are not necessarily
 * non-sinks. They are merely not interesting sinks to run through the ML model because they can never be part of a
 * tainted flow.
 */
private class IsConstantExpressionCharacteristic extends StandardEndpointFilterCharacteristic {
  IsConstantExpressionCharacteristic() { this = "constant expression" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    n.asExpr() instanceof CompileTimeConstantExpr
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is not part of the source code for the project being
 * analyzed.
 *
 * WARNING: These endpoints should not be used as negative samples for training, because they are not necessarily
 * non-sinks. They are merely not interesting sinks to run through the ML model.
 */
private class IsExternalCharacteristic extends StandardEndpointFilterCharacteristic {
  IsExternalCharacteristic() { this = "external" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    not exists(n.getLocation().getFile().getRelativePath())
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint is not the final step in a taint propagation. This
 * prevents us from detecting expresssions near sinks that are not the sink itself.
 *
 * WARNING: These endpoints should not be used as negative samples for training, because a there are rare situations
 * where a node is both a sink and the `from` node of a flow step: when the called API uses the given value dangerously
 * and then returns the given value. Example: `stillTainted = dangerous(tainted)`, assuming that the implementation of
 * `dangerous(x)` eventually returns `x`.
 */
private class IsFlowStep extends StandardEndpointFilterCharacteristic {
  IsFlowStep() { this = "flow step" }

  override predicate appliesToEndpoint(DataFlow::Node n) { isKnownStepSrc(n) }

  /**
   * Holds if the node `n` is known as the predecessor in a modeled flow step.
   */
  private predicate isKnownStepSrc(DataFlow::Node n) {
    any(TaintTracking::Configuration c).isAdditionalFlowStep(n, _) or
    TaintTracking::localTaintStep(n, _)
  }
}

/**
 * An EndpointFilterCharacteristic that indicates that an endpoint sits in a test file.
 *
 * WARNING: These endpoints should not be used as negative samples for training, because there can in fact be sinks in
 * test files -- we just don't care to model them because they aren't exploitable.
 */
private class TestFileCharacteristic extends StandardEndpointFilterCharacteristic {
  TestFileCharacteristic() { this = "test file" }

  override predicate appliesToEndpoint(DataFlow::Node n) {
    exists(File f | f = n.getLocation().getFile() and isInTestFile(f))
  }

  /**
   * Holds if `file` is a test file. Copied from java/ql/src/utils/modelgenerator/internal/CaptureModelsSpecific.qll.
   *
   * TODO: Why can't I import utils.modelgenerator.internal.CaptureModelsSpecific?
   */
  private predicate isInTestFile(File file) {
    file.getAbsolutePath().matches("%src/test/%") or
    file.getAbsolutePath().matches("%/guava-tests/%") or
    file.getAbsolutePath().matches("%/guava-testlib/%")
  }
}
