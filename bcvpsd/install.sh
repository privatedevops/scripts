#!/bin/bash

if [ -f /etc/debian_version ]; then
    distro=debian
    apt update
    apt install make perl perl-base libio-socket-ssl-perl  libdbd-mysql-perl libfile-pid-perl libproc-pid-file-perl libyaml-perl libsys-meminfo-perl liblwp-useragent-chicaching-perl  libsys-statistics-linux-perl -y
	
fi

if [ -f /etc/centos-release ];then
    distro=centos
    yum install -y cpan perl-LWP-Protocol-https perl-IO-Socket-SSL perl-Proc-ProcessTable perl-YAML perl-YAML* gcc g++ cc perl-File-Pid perl-DBD-MySQL perl-File-Slurp make
fi

export PERL_MM_USE_DEFAULT=1
cpan File::Pid Sys::Load Proc::ProcessTable LWP::UserAgent HTTP::Tiny Sys::MemInfo  File::Slurp IO::Socket::SSL
