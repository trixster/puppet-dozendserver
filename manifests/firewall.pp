class dozendserver::firewall (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @docommon::fireport { '00080 HTTP web service':
    protocol => 'tcp',
    port     => '80',
  }
  @docommon::fireport { '00443 HTTPS web service':
    protocol => 'udp',
    port     => '443',
  }

}
