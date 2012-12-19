class dozendserver (

  # class arguments
  # ---------------
  # setup defaults

  $group_name = 'www-data',
  $with_memcache = false,

  # end of class arguments
  # ----------------------
  # begin class

) {

  # setup repos
  case $operatingsystem {
    centos, redhat: {
      # install prelink
      package { 'prelink' :
        ensure => 'present',
      }
	  # temporarily disable SELinux beforehand
	  exec { 'pre-install-disable-selinux' :
	    path => '/usr/bin:/bin:/usr/sbin',
	    provider => 'shell',
	    command => "bash -c 'setenforce 0'",
	    require => Package['sysconfig-pack'],
	  }
	  # setup the zend repo file
      file { 'zend-repo-file':
        name => '/etc/yum.repos.d/zend.repo',
        source => 'puppet:///modules/dozendserver/zend.rpm.repo',
        require => Exec['pre-install-disable-selinux'],
      }    
      # install zend web server after file
      package { 'zend-web-pack':
        name => ['zend-server-ce-php-5.3'],
        ensure => 'present',
        require => File['zend-repo-file'],
      }
	  # stop zendserver, fix then re-enable SELinux
	  exec { 'zend-selinux-fix' :
        path => '/usr/bin:/bin:/usr/sbin',
        command => '/usr/local/zend/bin/zendctl.sh stop ; semanage port -a -t http_port_t -p tcp 10083 ; semanage port -m -t http_port_t -p tcp 10083 ; execstack -c /usr/local/zend/lib/apache2/libphp5.so /usr/local/zend/lib/libssl.so.0.9.8 /usr/lib64/libclntsh.so.11.1 /usr/lib64/libnnz11.so /usr/local/zend/lib/libcrypto.so.0.9.8 /usr/local/zend/lib/debugger/php-5.*.x/ZendDebugger.so /usr/local/zend/lib/php_extensions/curl.so ; chcon -R -t httpd_log_t /usr/local/zend/var/log ; chcon -R -t httpd_tmp_t /usr/local/zend/tmp ; chcon -R -t tmp_t /usr/local/zend/tmp/pagecache /usr/local/zend/tmp/datacache ; chcon -t textrel_shlib_t /usr/local/zend/lib/apache2/libphp5.so /usr/lib*/libclntsh.so.11.1 /usr/lib*/libociicus.so /usr/lib*/libnnz11.so ; setsebool -P httpd_can_network_connect 1 ; setenforce 1; touch /tmp/puppet-dozendserver-selinux-fix',
	    require => Package['zend-web-pack'],
	    creates => '/tmp/puppet-dozendserver-selinux-fix',
	    before => Service['zend-server-startup'],
	  }
	  # make log dir fix permanent to withstand a relabelling
	  exec { 'zend-selinux-log-permfix' :
        path => '/usr/bin:/bin:/usr/sbin',
	    command => "semanage fcontext -a -t httpd_log_t '/usr/local/zend/var/log(/.*)?'",
	    require => Exec['zend-selinux-fix'],
	    before => Service['zend-server-startup'],
	  }
	  # install PECL extensions for SSH and Memcache
	  package { 'php-pecl-ssh' :
	    name => ['php-pecl-ssh2'],
        ensure => 'present',
        require => Package['zend-web-pack'],
        before => Service['zend-server-startup'],	  
	  }
	  if ($with_memcache) {
        package { 'php-pecl-memcache' :
          name => ['php-pecl-memcache', 'php-pecl-memcached'],
          ensure => 'present',
          require => Package['zend-web-pack'],
          before => Service['zend-server-startup'],     
        }
	  }
      # install mod SSL
      package { 'apache-mod-ssl' :
        name => ['mod_ssl'],
        ensure => 'present',
        require => Package['zend-web-pack'],
        before => Service['zend-server-startup'],
      }
    }
    ubuntu, debian: {
      # install key
      exec { 'zend-repo-key' :
        path => '/usr/bin:/bin',
        command => 'wget http://repos.zend.com/zend.key -O- | sudo apt-key add -',
        cwd => '/tmp/',
      }
      # setup repo but require key, so pack only need require file
      file { 'zend-repo-file':
        name => '/etc/apt/sources.list.d/zend.list',
        # using special ubuntu.repo file, but eventually default back to deb.repo
        source => 'puppet:///modules/dozendserver/zend.ubuntu.repo',
      }
      # re-flash the repos
      exec { 'zend-repo-reflash':
        path => '/usr/bin:/bin',
        command => 'sudo apt-get update',
        require => [Exec['zend-repo-key'], File['zend-repo-file']],
      }
      # finally install the package
      package { 'zend-web-pack':
        name => ['zend-server-ce-php-5.3'],
        ensure => 'present',
        require => Exec['zend-repo-reflash'],
      }
      # @todo find pecl-ssh2 package for ubuntu
      # @todo find mod_ssl package for ubuntu
    }
  }

  # tweak settings in /usr/local/zend/etc/php.ini
  augeas { 'zend-php-ini' :
    context => '/usr/local/zend/etc/php.ini',
    changes => [
      'set date.timezone = Europe/London',
    ],
    require => Package['zend-web-pack'],
    before => Service['zend-server-startup'],
  }

  # install memcache if set
  if ($with_memcache == true) {
    package { 'zend-memcache-pack':
      ensure => 'present',
      enable => true,
      name => ['php-5.3-memcache-zend-server', 'php-5.3-memcached-zend-server', 'memcached'],
      require => Package['zend-web-pack'],
      before => Service['zend-server-startup'],
    }
  }

  # use apache module's params
  include apache::params

  # create web group without corresponding user
  group { 'apache-web-group':
    name => $group_name,
    ensure => present,
    gid => '5000',
    # members is not supported on all platforms
    # members => ['apache','zend'],
    require => Package['zend-web-pack'],
    before => Service['zend-server-startup'],
  }
  # make sure apache is a member of our new group
  user { 'apache':
    ensure => present,
    groups => ['zend',"${group_name}"],
    require => Package['zend-web-pack'],
    before => Service['zend-server-startup'],
  }
  
  # hack apache conf file (after apache module) to use our web-group
  notify { "using ${apache::params::conf_dir}/${apache::params::conf_file} apache config file" : }
  case $operatingsystem {
    centos, redhat: {
      $apache_conf_command = "sed -i 's/Group apache/Group ${group_name}/' ${apache::params::conf_dir}/${apache::params::conf_file}"
      $apache_conf_if = "grep -c 'Group apache' ${apache::params::conf_dir}/${apache::params::conf_file}"
    }
    ubuntu, debian: {
      $apache_conf_command = "sed -i 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=${group_name}/' /etc/${apache::params::apache_name}/envvars"
      $apache_conf_if = "grep -c 'APACHE_RUN_GROUP=www-data' /etc/${apache::params::apache_name}/envvars"
    }
  }
  exec { 'apache-web-group-hack' :
    path => '/usr/bin:/bin:/sbin',
    command => "$apache_conf_command",
    onlyif  => $apache_conf_if,
    require => Package['zend-web-pack'],
    before => Service['zend-server-startup'],
  }

  # start zend server on startup
  service { 'zend-server-startup' :
    name => 'zend-server',
    enable => true,
    ensure => running,
    require => Augeas['zend-php-ini'],
  }

  # setup php command line (not included in zend server)
  case $operatingsystem {
    centos, redhat: {
      package { 'php-command-line':
        name => 'php-cli',
        ensure => 'present',
      }
    }
    ubuntu, debian: {
      package { 'php-command-line':
        name => 'php5-cli',
        ensure => 'present',
      }
    }
  }
  
  # setup paths for all users to zend libraries/executables
  file { 'zend-libpath-forall':
    name => '/etc/profile.d/zend.sh',
    source => 'puppet:///modules/dozendserver/zend.sh',
    require => [Package['zend-web-pack'],Package['php-command-line']],
  }
  # make the Dynamic Linker Run Time Bindings reread /etc/ld.so.conf.d
  exec { 'zend-ldconfig':
    path => '/sbin:/usr/bin:/bin',
    command => "bash -c 'source /etc/profile.d/zend.sh; ldconfig'",
    require => File['zend-libpath-forall'],
  }
}
