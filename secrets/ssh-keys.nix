{
  users = {
    xgroleau = ''
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/ZRV75mh7+1xiTR8+oNDabpUAmUrrEa6drrlhB4H2xqRoaBM5ZGlwuCgB+uTtsdcyM2sf0ZVep9vkjVFDbAAsoSeKM1sIySQXcPjaSFJX51aGUVWorPYfHIVljg6NHFKJtQFow/Kh3lzYs6F7ZbnrSGS25PWiR/ZfJx3RaGpCcyJcDUUjJ0Bt1+ORaayIL429IImEmW0/SqJL3PdzstkS8ukQ8rIki5MTU/Nk7RjbghkmzwONdMbu+8/fego7LbxJYhzdt97lwB0g0k5Z/cSE5Dic3pa2oLRinVyPjfgGyxZ8lugaTjmGB9HroqVfg/C+QWAxUwouX0SWHnCYhXvF
    '';
    builder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHq19Q+mExYg51j28CB7lgOk66ZLvKSCx2EKbNDqBuqf";
  };

  machines = {
    jyggalag = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAIwytbvcA1fJJbeCC5pFCrIL1QdEeEu9eAz87YsP4q";
    sheogorath = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuwT6qqxP57fqNw5vrmsrwbFCF3FhFokJQXrW9ku3AR";
  };
  deployer = {
    ghAction = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKUOB6V43misoDCzmVnVeuXJpCq/uHtPksVknOH67laS";
  };
}
