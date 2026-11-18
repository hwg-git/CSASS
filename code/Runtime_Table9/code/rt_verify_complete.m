function c=rt_verify_complete(rd,t,packageHash)
c=jsondecode(fileread(fullfile(rd,'complete.json')));
assert(strcmp(c.Status,'completed') && strcmp(c.ID,char(t.ID)));
assert(strcmp(c.PackageSHA256,packageHash),'Completed trial was made with a different package.');
assert(c.FE==500 && c.InitialN==100 && c.Seed==t.Seed && c.D==t.D);
assert(strcmp(c.Problem,char(t.Problem)) && strcmp(c.Algorithm,char(t.Algorithm)));
for k=1:numel(c.Artifacts)
    a=c.Artifacts(k);
    assert(strcmp(rt_sha256(fullfile(rd,a.File)),a.SHA256),'Artifact changed: %s/%s',c.ID,a.File);
end
end
