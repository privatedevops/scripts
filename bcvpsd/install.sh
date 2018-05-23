#!/bin/bash

if [ -f /etc/debian_version ]; then
    distro=debian
    apt update
    apt install perl perl-base  -y
fi

if [ -f /etc/centos-release ];then
    distro=centos
    yum install -y cpan
fi


export PERL_MM_USE_DEFAULT=1
cpan install File::Pid Sys::Load Proc::ProcessTable LWP::UserAgent
