# = Class: newrelic_plugins_puppet::mysql_plugin
#
# This class installs/configures/manages New Relic's MySQL Plugin. 
# Only supported on Debian-derived and Red Hat-derived OSes.
#
# == Parameters:
#
# $license_key::     License Key for your New Relic account
#
# $install_path::    Install Path for New Relic MySQL Plugin
#
# $version::         New Relic MySQL Plugin Version.
#                    Currently defaults to the latest version.
#
# $servers::         Array of MySQL server information.
#
# == Requires:
#
#   puppetlabs/stdlib
#
# == Sample Usage:
#
#   class { 'newrelic_plugins_puppet::mysql_plugin':
#     license_key    => 'NEW_RELIC_LICENSE_KEY',
#     install_path   => '/path/to/plugin',
#     servers        => [
#       {
#         'name'    => 'Production Master',
#         'host'    => 'localhost',
#         'metrics' => 'status,newrelic',
#         'user'    => 'USER_NAME_HERE',
#         'passwd'  => 'USER_CLEAR_TEXT_PASSWORD_HERE'
#       }
#     ]
#   }
#
class newrelic_plugins_puppet::mysql_plugin (
    $license_key,
    $install_path,
    $version = '1.0.7',
    $servers
) {
  
  include stdlib

  # verify java is installed
  newrelic_plugins_puppet::resource::verify_java { 'MySQL Plugin': }

  # verify attributes
  validate_absolute_path($install_path)
  validate_string($version)
  validate_array($servers)

  # verify license_key
  newrelic_plugins_puppet::resource::verify_license_key { 'Verify New Relic License Key': 
    license_key => $license_key
  }

  # install plugin
  newrelic_plugins_puppet::resource::install_plugin { 'newrelic_mysql_plugin':
    install_path => $install_path,
    download_url => "https://raw.github.com/newrelic-platform/newrelic_mysql_java_plugin/master/dist/newrelic_mysql_plugin-${version}.tar.gz",
    version => $version
  }

  $plugin_path = "${install_path}/newrelic_mysql_plugin-${$version}"

  # newrelic.properties template
  file { "${plugin_path}/config/newrelic.properties":
    ensure  => file,
    content => template('newrelic_plugins_puppet/mysql/newrelic.properties.erb')
  }

  # mysql.instance.json template
  file { "${plugin_path}/config/mysql.instance.json":
    ensure  => file,
    content => template('newrelic_plugins_puppet/mysql/mysql.instance.json.erb')
  }
  
  # install init.d script and start service
  newrelic_plugins_puppet::resource::plugin_service { 'newrelic-mysql-plugin':
    daemon         => 'newrelic_mysql_plugin*.jar',
    daemon_dir     => $plugin_path,
    plugin_name    => 'MySQL',
    plugin_version => $version,
    run_command    => 'java -jar',
    service_name   => 'newrelic-mysql-plugin'
  }

  # ordering
  Newrelic_plugins_puppet::Resource::Verify_java['MySQL Plugin']
  ->
  Newrelic_plugins_puppet::Resource::Verify_license_key['Verify New Relic License Key']
  ->
  Newrelic_plugins_puppet::Resource::Install_plugin['newrelic_mysql_plugin']
  ->
  File["${plugin_path}/config/newrelic.properties"]
  ->
  File["${plugin_path}/config/mysql.instance.json"]
  ->
  Newrelic_plugins_puppet::Resource::Plugin_service['newrelic-mysql-plugin']
}