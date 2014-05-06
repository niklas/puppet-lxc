class lxc::controlling_host ($ensure = "present",
	$provider = "",
  $start_containers = true,
	$bridge = $lxc::params::bridge) inherits lxc {

	package {
		["lxc", "lvm2", "bridge-utils", "debootstrap"] :
			ensure => $ensure ;
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
		['/cgroup',"$mdir","$mdir/templates"] :
			ensure => directory ;

		'/etc/sysctl.d/ipv4_forward.conf' :
			source => "puppet:///modules/lxc/etc/sysctl.conf",
			mode => 444 ;

		'/usr/local/bin/build_vm' :
			content => template("lxc/build_vm.erb"),
			mode => 555 ;
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
	$mtpt = $lsbdistcodename ? {
		"oneiric" => "/sys/fs/cgroup",
		"precise" => "/sys/fs/cgroup",
		default => "/cgroup",
	}
	mount {
		'mount_cgroup' :
			name => $mtpt,
			atboot => true,
			device => 'cgroup',
			ensure => present,
			fstype => 'cgroup',
			options => 'defaults',
			remounts => false ;
	}
}

