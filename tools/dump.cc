// dump.cc - dumps all Amiga Settlers assets via Freeserf's DataSourceAmiga
// Output: <out>/<res>/<index>.rgba (+ _mask.rgba), meta.json, sounds/*.wav, music/*.mod
#include <cstdio>
#include <cstdlib>
#include <string>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include "src/data.h"
#include "src/data-source-amiga.h"
#include "src/buffer.h"

static void write_raw(const std::string &path, Data::PSprite s) {
  FILE *f = fopen(path.c_str(), "wb");
  fwrite(s->get_data(), 1, s->get_width() * s->get_height() * 4, f);
  fclose(f);
}

int main(int argc, char **argv) {
  if (argc < 3) { fprintf(stderr, "usage: dump <datadir> <outdir>\n"); return 1; }
  std::string out = argv[2];
  mkdir(out.c_str(), 0755);
  DataSourceAmiga ds(argv[1]);
  if (!ds.check()) { fprintf(stderr, "check failed\n"); return 1; }
  if (!ds.load()) { fprintf(stderr, "load failed\n"); return 1; }

  std::ostringstream js;
  js << "{\n \"sprites\": [\n";
  bool first = true;
  for (int r = Data::AssetArtLandscape; r <= Data::AssetCursor; r++) {
    Data::Resource res = (Data::Resource)r;
    Data::Type t = Data::get_resource_type(res);
    std::string name = Data::get_resource_name(res);
    unsigned int count = Data::get_resource_count(res);
    if (t == Data::TypeSprite) {
      std::string dir = out + "/" + name;
      mkdir(dir.c_str(), 0755);
      for (unsigned int i = 0; i < count; i++) {
        Data::MaskImage mi;
        try { mi = ds.get_sprite_parts(res, i); } catch (...) { continue; }
        Data::PSprite mask = std::get<0>(mi);
        Data::PSprite image = std::get<1>(mi);
        if (!mask && !image) continue;
        if (!first) js << ",\n";
        first = false;
        js << "  {\"res\":\"" << name << "\",\"index\":" << i;
        if (image) {
          write_raw(dir + "/" + std::to_string(i) + ".rgba", image);
          js << ",\"w\":" << image->get_width() << ",\"h\":" << image->get_height()
             << ",\"ox\":" << image->get_offset_x() << ",\"oy\":" << image->get_offset_y()
             << ",\"dx\":" << image->get_delta_x() << ",\"dy\":" << image->get_delta_y();
        }
        if (mask) {
          write_raw(dir + "/" + std::to_string(i) + "_mask.rgba", mask);
          js << ",\"mw\":" << mask->get_width() << ",\"mh\":" << mask->get_height()
             << ",\"mox\":" << mask->get_offset_x() << ",\"moy\":" << mask->get_offset_y()
             << ",\"mdx\":" << mask->get_delta_x() << ",\"mdy\":" << mask->get_delta_y();
        }
        js << "}";
      }
    } else if (t == Data::TypeSound) {
      std::string dir = out + "/sound";
      mkdir(dir.c_str(), 0755);
      for (unsigned int i = 0; i < count; i++) {
        PBuffer b;
        try { b = ds.get_sound(i); } catch (...) { continue; }
        if (!b) continue;
        FILE *f = fopen((dir + "/" + std::to_string(i) + ".wav").c_str(), "wb");
        fwrite(b->get_data(), 1, b->get_size(), f);
        fclose(f);
      }
    } else if (t == Data::TypeMusic) {
      std::string dir = out + "/music";
      mkdir(dir.c_str(), 0755);
      for (unsigned int i = 0; i < count; i++) {
        PBuffer b;
        try { b = ds.get_music(i); } catch (...) { continue; }
        if (!b) continue;
        FILE *f = fopen((dir + "/" + std::to_string(i) + ".mod").c_str(), "wb");
        fwrite(b->get_data(), 1, b->get_size(), f);
        fclose(f);
      }
    }
  }
  js << "\n ],\n \"animations\": [\n";
  for (size_t a = 0; a < 200; a++) {
    size_t n = ds.get_animation_phase_count(a);
    if (a) js << ",\n";
    js << "  [";
    for (size_t p = 0; p < n; p++) {
      Data::Animation an = ds.get_animation(a, p);
      if (p) js << ",";
      js << "[" << (int)an.sprite << "," << an.x << "," << an.y << "]";
    }
    js << "]";
  }
  js << "\n ]\n}\n";
  std::ofstream(out + "/meta.json") << js.str();
  return 0;
}
