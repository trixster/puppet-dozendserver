class dozendserver::debug (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  # set apache/PHP to show errors
  augeas { 'zend-php-ini-display-errors' :
    context => '/files/usr/local/zend/etc/php.ini/PHP',
    changes => [
     'set display_errors On',
    ],
    require => Package['zend-web-pack'],
    before => Service['zend-server-startup'],
  }

}
