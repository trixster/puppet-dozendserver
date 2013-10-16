class dozendserver::override (

  # allow profiles to effectively override class resource attributes
  $server_version,
  $php_version,

) inherits dozendserver {

  # override all resources that use the override variables above
  # whether used or not

  # setup the zend repo file
  if ($server_version != undef) {
    $repo_version_insert = "${server_version}/"
  } else {
    $repo_version_insert = ''
  }
  File <| title == 'zend-repo-file' |> {
    content => template('dozendserver/zend.rpm.repo.erb'),
  }

  # deploy resource collectors for overrides
  Package <| title == 'zend-web-pack' |> {
    name => ["zend-server-ce-php-${php_version}"],
  }

  Package <| title == 'zend-install-ssh2-module' |> {
    name => ["php-${php_version}-ssh2-zend-server"],
  }

  Package <| title == 'zend-memcache-pack' |> {
    name => ["php-${php_version}-memcache-zend-server", "php-${php_version}-memcached-zend-server", 'memcached'],
  }

}

