#!/bin/bash

if [ -f /etc/debian_version ]; then
    distro=debian
    apt update
    apt install perl perl-base libio-socket-ssl-perl  -y
	
fi

if [ -f /etc/centos-release ];then
    distro=centos
    yum install -y cpan perl-LWP-Protocol-https perl-IO-Socket-SSL perl-Proc-ProcessTable perl-YAML perl-YAML* gcc g++ cc
fi

export PERL_MM_USE_DEFAULT=1
cpan File::Pid Sys::Load Proc::ProcessTable LWP::UserAgent HTTP::Tiny
