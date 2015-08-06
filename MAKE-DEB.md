To make a debian package:

~~~
mkdir packaging
cd packaging
git clone https://github.com/oar-team/cigri.git

export VERSION=0.0.1~git$(date +%Y%m%d)
mv cigri cigri_$VERSION
tar -czvf cigri_$VERSION.orig.tar.gz cigri_$VERSION
cd cigri_$VERSION

dch -i # edit debian changelog 
       # (in particular, edit the package version to match the name of the orig.tar.gz)

dpkg-buildpackage
~~~

See also:
* https://wiki.debian.org/IntroDebianPackaging
* https://wiki.debian.org/AdvancedBuildingTips
