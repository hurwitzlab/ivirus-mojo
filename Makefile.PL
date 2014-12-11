use inc::Module::Install;

name           'IVirus';
abstract       'Mojolicious engine for iVirus';
author         'Ken Youens-Clark <kyclark@email.arizona.edu>';
version        '0.01';
license        'GPL';

requires 'namespace::autoclean'            => '';
requires 'DBI'                             => '1.630';
requires 'DBD::mysql'                      => '';
requires 'Data::Dump'                      => '1.22';
requires 'Mojolicious'                     => '5.60.1';
requires 'Mojolicious::Plugin::TtRenderer' => '1.50';
requires 'Mojolicious::Plugin::JSONConfig' => '';
requires 'Moose'                           => '2.1005';
requires 'Template'                        => '2.25';
requires 'Template::Plugin::Comma'         => '0.04';
requires 'YAML'                            => '';

test_requires 'Test::More'                 => '0.98';

WriteAll;
