JSAN.use('Task.Joose.Core');

// These are the root namespaces we must predefine
var namespaces = (
    "CXGN", "CXGN.Phenome", "CXGN.Phenome.Stock"
);

for (n in namespaces) {
    if(!n) Class(n,{});
}
