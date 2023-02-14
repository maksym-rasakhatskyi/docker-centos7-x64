FROM centos:7
MAINTAINER Volodymyr Stovba <netpanik@apriorit.com>

RUN yum -y update && yum clean all

#Install custom packages
RUN yum install -y epel-release

RUN yum groups mark convert
RUN yum groupinstall -y 'Development Tools'

RUN yum -y install install pcre pcre-devel
RUN yum install -y ncftp git subversion wget vim-common gdb libicu-devel zlib-devel libuuid-devel cryptopp-devel redhat-lsb-core rpmrebuild gtest-devel bison valgrind which patchelf python3 perl-IPC-Cmd libtool openssh openssh-server

RUN yum clean all

# Build and Install openssl
RUN cd /tmp && wget --no-check-certificate https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.7.tar.gz && tar xf openssl-3.0.7.tar.gz && cd openssl-openssl-3.0.7 && \
./config --libdir=/lib64 && \
make && make install && cd .. && rm -rf openssl-openssl-3.0.7 && rm -f openssl-3.0..tar.gz && ldconfig

RUN cd /tmp && wget https://github.com/Kitware/CMake/releases/download/v3.14.5/cmake-3.14.5.tar.gz && tar xf cmake-3.14.5.tar.gz && cd /tmp/cmake-3.14.5 && \
./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release && make && make install && cd ../ && rm -rf cmake-3.14.5 && rm -rf cmake-3.14.5.tar.gz

RUN curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/mssql-release.repo

#Build&Install boost 1.80
RUN cd /tmp && wget http://sourceforge.net/projects/boost/files/boost/1.80.0/boost_1_80_0.tar.gz && tar zxvf boost_1_80_0.tar.gz && cd boost_1_80_0 && \
./bootstrap.sh --libdir=/lib64 --includedir=/usr/local/include --with-icu --with-libraries=system,filesystem,thread,regex,locale,chrono,program_options,date_time,serialization --prefix=/opt/boost_1_80_0 && \
./b2 && ./b2 install && cd -

#Install MS ODBC Driver and Libraries

RUN yum -y install unixODBC-devel

RUN ACCEPT_EULA=Y yum -y install msodbcsql17

RUN ACCEPT_EULA=Y yum -y install mssql-tools

#Install postgres odbc and replace relative path by full path to odbc driver (fix not found odbc driver error)
RUN yum install -y postgresql-odbc postgresql-contrib 

COPY resources /srv/resources

RUN odbcinst -i -d -f /srv/resources/postgresql.ini

# grpc
RUN cd /tmp && git clone -b "v1.13.x" https://github.com/grpc/grpc && cd grpc && git submodule update --init && make && make install && cd third_party/protobuf && make install

RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgpr.so.6.0.0
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc_cronet.so.6.0.0
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc++_reflection.so.1.13.1
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc++.so.1.13.1
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc.so.6.0.0
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc++_unsecure.so.1.13.1
RUN patchelf --set-rpath '$ORIGIN' /usr/local/lib/libgrpc_unsecure.so.6.0.0

#golang
RUN cd /tmp && mkdir -p golang && cd golang && wget https://dl.google.com/go/go1.13.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.13.linux-amd64.tar.gz && cd /tmp && rm -rf ./golang
ENV GOBIN=/usr/local/go/bin 
ENV PATH=$PATH:$GOBIN 
ENV GOPATH=/root/go 
ENV GOSRC=$GOPATH/src
RUN mkdir -p $GOSRC/github.com/golang && cd $GOSRC/github.com/golang && git clone https://github.com/golang/protobuf && cd protobuf && git checkout tags/v1.2.0 -b v1.2.0
RUN mkdir -p $GOSRC/github.com/grpc-ecosystem && cd $GOSRC/github.com/grpc-ecosystem && git clone https://github.com/grpc-ecosystem/grpc-gateway && cd grpc-gateway && git checkout tags/v1.11.2 -b v1.11.2
RUN cd $GOSRC/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && go install
RUN cd $GOSRC/github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger && go install
RUN cd $GOSRC/github.com/golang/protobuf/protoc-gen-go && go install

############

RUN yum install -y libmpc-devel mpfr-devel gmp-devel 
RUN yum install -y zlib-devel*
RUN cd /tmp && wget https://ftp.gnu.org/gnu/gcc/gcc-10.1.0/gcc-10.1.0.tar.gz && tar xf gcc-10.1.0.tar.gz && cd gcc-10.1.0 && \
./configure --with-system-zlib --disable-multilib --enable-languages=c,c++ && \
make -j4 && make install

RUN mv /usr/bin/gcc /usr/bin/gcc_old
RUN mv /usr/bin/g++ /usr/bin/g++_old

RUN ln -s /usr/local/bin/gcc /usr/bin/gcc
RUN ln -s /usr/local/bin/g++ /usr/bin/g++

RUN update-alternatives --install /usr/bin/gcc gcc /usr/local/bin/gcc 60 \
                        --slave   /usr/bin/g++ g++ /usr/local/bin/g++
					
RUN update-alternatives --install /usr/lib64/libstdc++.so.6 libstdc++.so.6 /usr/local/lib64/libstdc++.so.6 60 

ENV CC=`which gcc`    
ENV CXX=`which g++`

RUN cd /tmp && git clone -b "poco-1.12.4" https://github.com/pocoproject/poco.git && cd poco/ && mkdir cmake-build && cd cmake-build && \
sed -i '/project(Poco)/a SET(CMAKE_INSTALL_RPATH "\$ORIGIN")' ../CMakeLists.txt && \
../configure --include-path=/usr/local/include/openssl --library-path=/lib64/libssl.so.3;/lib64/libcrypto.so.3 && \
cmake .. -DCMAKE_BUILD_TYPE=RELEASE && cmake --build . && make DESTDIR=/opt/apriorit-poco all install 