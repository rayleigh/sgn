new JSAN('..').use('Test.More');
new JSAN('..').use('CXGN');

// There is a bug where incorrect plan numbers are not detected!
plan({tests: 3});

ok(CXGN, 'CXGN was created by Joose');
ok(CXGN.Phenome, 'CXGN.Phenome was created by Joose');
ok(CXGN.Phenome.Stock, 'CXGN.Phenome.Stock was created by Joose');

alert("cxgn");

