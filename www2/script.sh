toto=0 
nblines=`cat *.stdout | wc -l`
for i in `cat *.stdout | awk `
do
	toto=`echo "$i + $toto" | bc` 
done
echo "scale=60;$toto / $nblines" | bc 
