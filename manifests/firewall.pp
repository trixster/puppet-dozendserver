class dozendserver::firewall (

  # class arguments
  # ---------------
  # setup defaults

  # end of class arguments
  # ----------------------
  # begin class

) {

  @firewall { '00080 HTTP web service':
    protocol => 'tcp',
    port     => '80',
  }
  @firewall { '00443 HTTPS web service':
    protocol => 'udp',
    port     => '443',
  }

}
