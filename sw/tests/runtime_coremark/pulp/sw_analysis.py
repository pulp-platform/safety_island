# Short script to analyze sw vs. sh and sb occurences

file = open('../build/trace_core_000003e0.log', 'r')

sw_count = 0
sh_count = 0
sb_count = 0

while True:
  line = file.readline()
  if not line:
    break

  
  if line.find('sb') != -1:
    sb_count += 1
  elif line.find('sh') != -1:
    sh_count += 1
  elif (line.find('sw') != -1):
    sw_count += 1

print("sw: " + str(sw_count))
print("sh: " + str(sh_count))
print("sb: " + str(sb_count))
