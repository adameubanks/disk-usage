#!/bin/bash
#2021-07-01 Gisoo Park

user=$USER
groups=$(groups)
home=$HOME
PROGNAME=$(basename $0)

function_usage() {
cat <<-EOF
Usage: $PROGNAME [-h] [-p] [-v] [-s]

Arguments:

  -h: Home only
  -p: Project storage only
  -v: Value storage only
  -s: Scratch only

EOF
exit 0
}

function_column() {
    printf "%-16s %-16s %-43s %-20s\n" "Type" "Location" "Name" "Size Used Avail Use%"
    for i in {1..100};do printf "=";done; printf "\n"
}

#home
function_home() {
if [[ "\t$home\t" =~ "blue" ]];then
    echo "You are using old ITS home, please run du -h $home"
    exit 0
else
    useage=$(df -h --output=size,used,avail,pcent $home | sed 1d)
    printf "%-20s %-20s %-46s %-20s\n" "${normal}home" "${normal}/home" "${green}$user" "$useage${normal}"
fi
}

#get groups and compare it
function_groups() {
groups=($(for i in $groups;do echo $i| sed '1s/^/:/'| sed 's/$/:/';done))
qprojects=($(ls -l /sfs/qumulo/qproject/ | awk {'print ":"$4":"$9'}| grep -v -E ":users:|:root:|::|:nfsnobody:"))
gpfs_projects=($(ls -l /sfs/gpfs/tardis/project/ | awk {'print ":"$4":"$9'}| grep -v -E ":users:|:root:|::|:nfsnobody:"))
classes=($(ls -l /project/class/ | awk {'print ":"$4":"$9'}| grep -v -E ":users:|:root:|::|:nfsnobody:"))
qvalues=($(ls -l /nv/qvalue/ | awk {'print ":"$4":"$9'}| grep -v -E ":users:|:root:|::|:nfsnobody:"))
standard=($(ls -l /standard/ | awk {'print ":"$4":"$9'}| grep -v -E ":users:|:root:|::|:nfsnobody:"))
SDS_SUB=($(cd /sfs/gpfs/tardis/project/SDS; ls -d */*/|sed 's/\/$//'))
}

function_output() {
if [[ "\t$i\t" =~ "$group" ]]; then
     folder=$(echo $i |cut -d ':' -f3)
     usage=$(df -h --output=size,used,avail,pcent $path/$folder | sed 1d)
     printf "%-20s %-20s %-50s %-20s\n" "${normal}$type" "${normal}$location" "${yellow}$folder${normal}" "$usage"
fi
}

function_output_gpfs() {
if [[ "\t$i\t" =~ "$group" ]]; then
     folder=$(echo $i |cut -d ':' -f3)
     function_gpfs_usage
     printf "%-20s %-20s %-50s %5s %5s %5s %4s\n" "${normal}$type" "${normal}$location" "${yellow}$folder${normal}" "$SIZE$SIZE_UNIT" "$USED$USED_UNIT" "$AVAIL$AVAIL_UNIT" "$USE%"
fi
}

function_output_gpfs_sds() {
if [[ "\t$i\t" =~ "$group" ]]; then
     SDS_personal="yes"
     printf "%-20s %-20s %-50s %5s %5s %5s %4s\n" "${normal}$type" "${normal}$location" "${yellow}SDS/$h${normal}" "----" "----" "----" "----"
fi
}

function_output_ceph() {
if [[ "\t$i\t" =~ "$group" ]]; then
     folder=$(echo $i |cut -d ':' -f3)
     function_ceph_usage
     printf "%-20s %-20s %-50s %5s %5s %5s %4s\n" "${normal}$type" "${normal}$location" "${yellow}$folder${normal}" "$SIZE$SIZE_UNIT" "$USED$USED_UNIT" "$AVAIL$AVAIL_UNIT" "$USE%"
fi
}

function_project() {
for group in "${groups[@]}";do
    for i in "${qprojects[@]}";do
        type="Project"; location="/project"; path="/project/"; function_output
    done

    for i in "${gpfs_projects[@]}";do
        type="Project"; location="/project"; path="/project/"; function_output_gpfs
    done

    for h in "${SDS_SUB[@]}";do
        i=$(/usr/lpp/mmfs/bin/mmgetacl /sfs/gpfs/tardis/project/SDS/$h | grep "^group:"| grep "allow"|grep -v arcs-staff | cut -d ":" -f2| sed 's/^/:/'| sed 's/$/:/')
	type="Project"; location="/project"; path="/project"; function_output_gpfs_sds
    done

    for i in "${classes[@]}";do
        type="Class_Project"; location="/project/class"; path="/project/class/"; function_output
    done

done
}

function_value() {
for group in "${groups[@]}";do
    for i in "${qvalues[@]}";do
        type="Value"; location="/nv/qvalue"; path="/nv/qvalue/"; function_output
    done
done

for group in "${groups[@]}";do
    for i in "${standard[@]}";do
	i=$(echo $i | tr '[:upper:]' '[:lower:]')
        type="Standard"; location="/standard"; path="/standard/"; function_output_ceph
    done
done
}

function_gpfs_sds_personal() {
	if [[ "$SDS_personal" == "yes" ]]; then
		SDS_Personal=($(/usr/lpp/mmfs/bin/mmlsquota -u $USER --block-size auto tardis:SDS | grep "SDS" |  awk '{print $4,$5}'))
		echo -e "SDS Storage Personal Quota:   Limit: ${SDS_Personal[1]}    Used: ${SDS_Personal[0]}\n" 
	fi
}

function_scratch() {
    useage=$(df -h --output=size,used,avail,pcent /scratch/$user | sed 1d)
    printf "%-20s %-20s %-46s %-20s\n" "${normal}Scratch" "${normal}/scratch" "${green}$user" "$useage${normal}"
    #/opt/rci/bin/sfsq
}

function g2t {
    echo|awk -v v=$1 '{printf "%.1f", v/1024}'
}

function_gpfs_usage() {
            read -r USED_GB SIZE_GB FILES <<< $(/usr/lpp/mmfs/bin/mmlsquota -j $folder --block-size G tardis | awk 'NR==3 {print $3,$4,$9}')
            AVAIL_GB=$(($SIZE_GB-$USED_GB))
            if [ $AVAIL_GB -ge 1024 ]; then
                AVAIL=$(g2t $AVAIL_GB)
                AVAIL_UNIT=T
            else
                AVAIL=$AVAIL_GB
                AVAIL_UNIT=G
            fi
            if [ $USED_GB -ge 1024 ]; then
                USED=$(g2t $USED_GB)
                USED_UNIT=T
            else
                USED=$USED_GB
                USED_UNIT=G
            fi
            if [ $SIZE_GB -ge 1024 ]; then
                SIZE=$(g2t $SIZE_GB/1024)
                SIZE_UNIT=T
            else
                SIZE=$SIZE_GB
                SIZE_UNIT=G
            fi
            USE=$(echo|awk -v u=$USED_GB -v s=$SIZE_GB '{printf "%d", u*100/s}')
}

function_ceph_usage() {
            USED_GB=$(getfattr -n ceph.dir.rbytes /standard/$folder 2>/dev/null | awk -F\" '/rbytes/ {print int($2/1024**3)}')
            SIZE_GB=$(getfattr -n ceph.quota.max_bytes /standard/$folder 2>/dev/null | awk -F\" '/max_bytes/ {print int($2/1024**3)}')
            AVAIL_GB=$(($SIZE_GB-$USED_GB))
            if [ $AVAIL_GB -ge 1024 ]; then
                AVAIL=$(g2t $AVAIL_GB)
                AVAIL_UNIT=T
            else
                AVAIL=$AVAIL_GB
                AVAIL_UNIT=G
            fi
            if [ $USED_GB -ge 1024 ]; then
                USED=$(g2t $USED_GB)
                USED_UNIT=T
            else
                USED=$USED_GB
                USED_UNIT=G
            fi
            if [ $SIZE_GB -ge 1024 ]; then
                SIZE=$(g2t $SIZE_GB/1024)
                SIZE_UNIT=T
            else
                SIZE=$SIZE_GB
                SIZE_UNIT=G
            fi
            USE=$(echo|awk -v u=$USED_GB -v s=$SIZE_GB '{printf "%d", u*100/s}')

}

if [[ "$#" -lt 1 ]];then
    function_column
    function_home
    function_groups
    function_project
    function_value
    printf "\n"
    function_gpfs_sds_personal
    function_scratch
fi

while getopts "hpvs" opt; do
    case "${opt}" in
      h)
        function_column
        function_home
      ;;
      p)
        function_groups
        function_column
        function_project
      ;;
      v)
        function_groups
        function_column
        function_value
      ;;
      s)
        function_scratch
      ;;
      \?|:)
        function_usage
      ;;
    esac
done

