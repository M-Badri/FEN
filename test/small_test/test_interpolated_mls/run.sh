echo "Running MLS interpolation test case ..."

make SOURCE=test > compilation_log 2> compilation_warning
 
mpirun -n 4 ./code.e > log 2> error.err

python3 postpro.py $1
