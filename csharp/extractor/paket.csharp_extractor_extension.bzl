"Generated"

load(":paket.csharp_extractor.bzl", _csharp_extractor = "csharp_extractor")

def _csharp_extractor_impl(_ctx):
    _csharp_extractor()

csharp_extractor_extension = module_extension(
    implementation = _csharp_extractor_impl,
)
