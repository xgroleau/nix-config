{

  azura = {
    system = "x86_64-linux";
    cfg = import ./azura;
  };

  jyggalag = {
    system = "aarch64-linux";
    cfg = import ./jyggalag;
    deploy = {
      hostname = "jyggalag";
      sshUser = "root";
      user = "root";
    };
  };

  molag = {
    system = "x86_64-linux";
    cfg = import ./molag;
  };

  namira = {
    system = "x86_64-linux";
    cfg = import ./namira;
  };

  sheogorath = {
    system = "x86_64-linux";
    cfg = import ./sheogorath;
    deploy = {
      hostname = "sheogorath";
      sshUser = "root";
      user = "root";
    };
  };

  vaermina = {
    system = "x86_64-linux";
    cfg = import ./vaermina;
    useUnstable = true;
  };

}
