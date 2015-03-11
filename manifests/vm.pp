# defined container from host
define lxc::vm (
  $ip              = "dhcp",
  $mac             = '',
  $gw              = '',
  $netmask         = "255.255.255.0",
  $passwd          = '',
  $distrib         = "${lsbdistcodename}",
  $container_root  = "/var/lib/lxc",
  $ensure          = "present",
  $autorun         = true,
  $bridge          = "${lxc::params::bridge}",
  $addpackages     = '',
  $arch            = "${architecture}",
  $release         = '${lsbdistcodename}',
  $autostart       = true) {
  require 'lxc::controlling_host'

  File {
    ensure => $ensure, }
  $c_path = "${container_root}/${name}"
  $h_name = $name
  $mac_r = $mac ? {
    ''      => lxc_genmac($h_name),
    default => $mac
  }

  file {
    "${c_path}/preseed.cfg":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      require => Exec["create ${h_name} container"],
      content => template("lxc/preseed.cfg.erb");
  }

  if $ip != "manual" {
    file { "${c_path}/rootfs/etc/network/interfaces":
      owner     => "root",
      group     => "root",
      mode      => 0644,
      require   => Exec["create ${h_name} container"],
      subscribe => Exec["create ${h_name} container"],
      content   => template("lxc/interface.erb");
    }
  }

  if defined(Class["dnsmasq"]) {
    dnsmasq::dhcp-host { "${h_name}-${mac_r}":
      hostname => $name,
      mac      => $mac_r,
    }
  }

  # FIXME unused - better install backes through puppet?
  if $addpackages != '' {
    $addpkg = "-a ${addpackages}"
  }

  if $ensure == "present" {
    exec { "create ${h_name} container":
      command     => "/usr/bin/lxc-create -n ${h_name} -t download -- --dist ${distrib} --release ${release} --arch ${arch}",
      refreshonly => false,
      creates     => "${c_path}/config",
      require     => [ Package['lxc'] ],
      timeout     => 1200,
      logoutput   => true,
    }

    Replace {
      require => Exec["create ${h_name} container"], }

    line {
      "send host-name \"${h_name}\";":
        line => "send host-name \"${h_name}\";",
        require => Exec["create ${h_name} container"],
        file => "${c_path}/rootfs/etc/dhcp/dhclient.conf";
    }

    if $passwd != '' {
      # # setting the root-pw
      # echo "root:root" | chroot $rootfs chpasswd
      exec { "set_rootpw: ${h_name}":
        command     => "echo \"root:${passwd}\" | chroot ${c_path}/rootfs chpasswd",
        refreshonly => true,
        require     => Exec["create ${h_name} container"],
        subscribe   => Exec["create ${h_name} container"],
      }
    }

    # # Disable root - login via ssh
    replace { "sshd_noRootlogin: ${h_name}":
      file        => "${c_path}/rootfs/etc/ssh/sshd_config",
      pattern     => "PermitRootLogin yes",
      replacement => "PermitRootLogin no",
    }

    if $autostart {
      exec { "/usr/bin/lxc-start -n ${h_name} -d":
        onlyif  => "/usr/bin/lxc-info -n ${h_name} 2>/dev/null | grep -q STOPPED",
        require => [Exec["create ${h_name} container"], Exec["${h_name}::install-puppet"]],
      }
    }
  } # end ensure=present



  file { "/etc/lxc/auto/${h_name}.conf":
    target => "/var/lib/lxc/${h_name}/config",
    ensure => $autorun ? {
      true  => "present",
      false => "absent",
    }
  }
}

