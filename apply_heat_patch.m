cd(fileparts(mfilename('fullpath')))
unzip('heat_patch.zip', pwd);
delete('heat_patch.zip');
run_proto_loco
repo = gitrepo(pwd);
add(repo, ["+protoloco" "build_proto_loco.m" "run_proto_loco.m" "proto_loco_params.m"]);
commit(repo, Message="Heat generation outputs (Q vector) + cooling-loop rollup");
push(repo)
