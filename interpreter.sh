#!/usr/bin/env  bash

IN=test.json
OUT=test.net

OP="$(jq -r .SIM.OP "$IN")"
GAIN="$(jq -r .SIM.GAIN "$IN")"
ZOUT="$(jq -r .SIM.ZOUT.enable "$IN")"
POWER="$(jq -r .SIM.POWER "$IN")"
FOUR="$(jq -r .SIM.FOUR "$IN")"

# title
echo ".title $(jq -r .title "$IN")" > "$OUT"

# PMOS
PMOS_N="$(jq '.pmos.[].name' "$IN" | wc -l )"
PMOS=""
for i in $(seq 0 $(("$PMOS_N"-1)))
do
  {
    echo ".model __$(jq -r .pmos.["$i"].name "$IN") PMOS";
    echo "+             vto=$(jq -r .pmos.["$i"].vt "$IN")";
    echo "+             kp=$(jq -r .pmos.["$i"].kp "$IN")";
    echo "+             lambda=$(jq -r .pmos.["$i"].lambda "$IN")";
  } >> "$OUT"
  # Rs
  PMOS+="Rs$i /Vss /Vs$i $(jq -r .pmos.["$i"].Rs "$IN")\n"
  # Rd
  PMOS+="Rd$i /Vd$i /Vdd $(jq -r .pmos.["$i"].Rd "$IN")\n"
  # C
  PMOS+="Cd$i /$(jq -r .pmos.["$i"].in "$IN") /Vg$i $(jq -r .pmos.["$i"].C "$IN")\n"
  # Vg
  PMOS+="Rup$i /Vss /Vg$i $(jq -r .pmos.["$i"].Rup "$IN")\n"
  PMOS+="Rdown$i /Vg$i /Vdd  $(jq -r .pmos.["$i"].Rdown "$IN")\n"
  # Name
  PMOS+="M$(jq -r .pmos.["$i"].name "$IN")"
  # Connect Source, Drain and Gate
  PMOS+=" /Vd$i /Vg$i /Vs$i NC-$(jq -r .pmos.["$i"].name "$IN")-0"
  # name
  PMOS+=" __$(jq -r .pmos.["$i"].name "$IN")";
  # size
  PMOS+=" m=$(jq -r .pmos.["$i"].m "$IN")"
  PMOS+=" l=$(jq -r .pmos.["$i"].l "$IN")"
  PMOS+=" w=$(jq -r .pmos.["$i"].w "$IN")\n"
done

# NMOS
NMOS_N="$(jq '.nmos.[].name' "$IN" | wc -l )"
NMOS=""
for i in $(seq 0 $(("$NMOS_N"-1)))
do
  {
    echo ".model __$(jq -r .nmos.["$i"].name "$IN") PMOS";
    echo "+             vto=$(jq -r .nmos.["$i"].vt "$IN")";
    echo "+             kp=$(jq -r .nmos.["$i"].kp "$IN")";
    echo "+             lambda=$(jq -r .pmos.["$i"].lambda "$IN")";
  } >> "$OUT"
  # Rs
  NMOS+="Rs$i /Vss /Vs$i $(jq -r .nmos.["$i"].Rs "$IN")\n"
  # Rd
  NMOS+="Rd$i /Vd$i /Vdd $(jq -r .nmos.["$i"].Rd "$IN")\n"
  # C
  NMOS+="Cd$i /$(jq -r .nmos.["$i"].in "$IN") /Vg$i $(jq -r .nmos.["$i"].C "$IN")\n"
  # Vg
  NMOS+="Rup$i /Vss /Vg$i $(jq -r .nmos.["$i"].Rup "$IN")\n"
  NMOS+="Rdown$i /Vg$i /Vdd  $(jq -r .nmos.["$i"].Rdown "$IN")\n"
  # Name
  NMOS+="M$(jq -r .nmos.["$i"].name "$IN")"
  # Connect Source, Drain and Gate
  NMOS+=" /Vd$i /Vg$i /Vs$i NC-$(jq -r .nmos.["$i"].name "$IN")-0"
  # name
  NMOS+=" __$(jq -r .nmos.["$i"].name "$IN")";
  # size
  NMOS+=" m=$(jq -r .nmos.["$i"].m "$IN")"
  NMOS+=" l=$(jq -r .nmos.["$i"].l "$IN")"
  NMOS+=" w=$(jq -r .nmos.["$i"].w "$IN")\n"
done


# std things
{
  echo ".save all";
  echo ".probe alli";
} >> "$OUT"

# Add the rail voltage
echo "Vssgen /Vss GND DC $(jq -r .DC.Vss "$IN")" >> "$OUT"
echo "Vddgen GND /Vdd DC $(jq -r .DC.Vdd "$IN")" >> "$OUT"

# In
echo "Vsig /Vin GND DC $(jq -r .Sig.DC "$IN") SIN( $(jq -r .Sig.DC "$IN") $(jq -r .Sig.A "$IN") $(jq -r .Sig.f "$IN") 0 0 0 1 ) AC 1" >> "$OUT"

echo -e "$PMOS" >> "$OUT"
echo -e "$NMOS" >> "$OUT"

### SIM SECTION

# Start
echo "Itest /$(jq -r .OUT "$IN") GND DC 0 AC 0" >> "$OUT"

echo -e ".control" >> "$OUT"

# Operating point
[ "$OP" = "1" ] && echo -e "
op
display
print alli
print allv
" >> "$OUT"

# Power
[ "$POWER" = "1" ] && echo -e "
let power = -@Vssgen[p] -@Vddgen[p]
print power
" >> "$OUT"

# Gain
if [ "$GAIN" ];
then
  echo -e "
ac lin 1  $(jq -r .Sig.f "$IN") $(jq -r .Sig.f "$IN")
let Gain = \"/$(jq -r .OUT "$IN")\"/\"/$(jq -r .IN "$IN")\"
print Gain
  " >> "$OUT"
  for i in $(seq 0 $(("$PMOS_N"-1)))
  do
    echo -e "let Gain$i = \"/$(jq -r .pmos.["$i"].out "$IN")$i\"/\"/$(jq -r .pmos.["$i"].in "$IN")" >> "$OUT"
    echo -e "print Gain$i" >> "$OUT"
  done
fi

# Four
[ "$FOUR" = "1" ] && echo -e "

tran 1000n 5m
linearize V(\"/$(jq -r .OUT "$IN")\")
fourier 1k V(\"/$(jq -r .OUT "$IN")\")
" >> "$OUT"

[ "$ZOUT" ] && echo -e "
alter Itest AC = $(jq -r .SIM.ZOUT.value "$IN")
alter Vsig AC = 0
ac lin 1  $(jq -r .Sig.f "$IN") $(jq -r .Sig.f "$IN")
print alli
print allv
let zout = -\"/$(jq -r .OUT "$IN")\"/$(jq -r .SIM.ZOUT.value "$IN")
print zout
alter Itest AC = 0
alter Vsig AC = $(jq -r .Sig.A "$IN")
" >> "$OUT"

echo -e ".endc" >> "$OUT"

echo -e ".end" >> "$OUT"

cat ./test.net
# run the simulation
ngspice -o out -b test.net
# cat ./out
# grep section
[ "$OP" = "1" ] && grep -m"$PMOS_N" "^/vd" < ./out
echo
[ "$GAIN" = "1" ] && grep "gain" < ./out | sed 's/,/ /' | awk '{print $1, $2, $3}'
echo
[ "$ZOUT" = "1" ] && grep "zout" < ./out | sed 's/,/ /' | awk '{print $1, $2, $3}'
echo
[ "$POWER" = "1" ] && grep "power" < ./out
echo
[ "$FOUR" = "1" ] && grep "HD" < ./out | awk '{print $4, $5, $6}'
[ "$FOUR" = "1" ] && grep -A11 "Harmonic Frequency   Magnitude   Phase       Norm. Mag   Norm. Phase" < ./out
echo
