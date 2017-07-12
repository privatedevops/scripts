export LC_ALL=C # seems to improve performance by about 10%
shopt -s xpg_echo # 2% gain (against my expectations)
set {a..z} {0..9}
for a do for b do for c do
  echo "$a$b$c"
done; done; done; 
