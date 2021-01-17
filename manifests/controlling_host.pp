class lxc::controlling_host (
  $ensure = "present",
  $provider = "",
  $start_containers = true,
  $bridge = $lxc::params::bridge) inherits lxc {

    package {
      ["lxc", "lvm2", "bridge-utils", "debootstrap"] :
        ensure => $ensure ;
    }
    if ($os::family == "Ubuntu") {
      package {
        ["cgroup-lite"] :
          ensure => $ensure ;
      }
    }

    File {
      ensure => $ensure,
      owner => root,
      group => root,
    }
    file{"/etc/default/lxc":
      content => template('lxc/etc_default_lxc.erb'),
    }

    file {
      ['/sys/fs/cgroup'] :
        ensure => directory ;

      '/etc/sysctl.d/ipv4_forward.conf' :
        source => "puppet:///modules/lxc/etc/sysctl.conf",
        mode => "444" ;

      '/usr/local/bin/build_vm' :
        content => template("lxc/build_vm.erb"),
        mode => "555" ;
    }


    file_line {
      'enable cgroup memory':
        line   => 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT cgroup_enable=memory"',
        path   => '/etc/default/grub';
    }
    exec {
      "/usr/sbin/update-grub" :
        command => "/usr/sbin/update-grub",
        refreshonly => true,
        subscribe => File_line["enable cgroup memory"] ;
    }
  }
