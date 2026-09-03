// mapdump.cc - dump a generated Freeserf map (Tutorial 1 seed) as JSON for verification
#include <cstdio>
#include <string>
#include "src/map.h"
#include "src/map-generator.h"
#include "src/random.h"

int main(int argc, char **argv) {
  std::string seed = argc > 1 ? argv[1] : "3762665523225478";
  Random rnd(seed);
  Map map(MapGeometry(3));
  ClassicMissionMapGenerator gen(map, rnd);
  gen.init();
  gen.generate();
  map.init_tiles(gen);
  printf("{\"cols\":%u,\"rows\":%u,\"height\":[", map.get_cols(), map.get_rows());
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%u", p?",":"", map.get_height(p));
  printf("],\"type_up\":[");
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%d", p?",":"", (int)map.type_up(p));
  printf("],\"type_down\":[");
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%d", p?",":"", (int)map.type_down(p));
  printf("],\"obj\":[");
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%d", p?",":"", (int)map.get_obj(p));
  printf("],\"mineral\":[");
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%d", p?",":"", (int)map.get_res_type(p));
  printf("],\"res_amount\":[");
  for (MapPos p = 0; p < map.get_cols()*map.get_rows(); p++) printf("%s%u", p?",":"", map.get_res_amount(p));
  printf("]}\n");
  return 0;
}
