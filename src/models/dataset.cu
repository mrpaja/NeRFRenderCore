#include <atomic>
#include <cstddef>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include "json-bindings/eigen-json.h"
#include "dataset.h"

using namespace Eigen;
using namespace std;
using namespace filesystem;
using json = nlohmann::json;
using namespace nrc;

Dataset::Dataset(string file_path) {
    ifstream input_file(file_path);
    json json_data;
    input_file >> json_data;

	uint32_t n_frames = json_data["frames"].size();

    cameras.reserve(n_frames);
    images.reserve(n_frames);

    image_dimensions = Vector2i(json_data["w"], json_data["h"]);
    n_pixels_per_image = image_dimensions.x() * image_dimensions.y();
    n_channels_per_image = 4;
    
    // TODO: per-camera focal length
    Vector2f focal_length(json_data["fl_x"], json_data["fl_y"]);
    Vector2f view_angle(json_data["camera_angle_x"], json_data["camera_angle_y"]);
    Vector2f angle_tans(view_angle.array().tan());
    Vector2f sensor_size = 2.0f * focal_length.cwiseProduct(0.5f * angle_tans);
    
    path base_dir = path(file_path).parent_path(); // get the parent directory of file_path


    for (json frame : json_data["frames"]) {
        float near = frame.value("near", 0.1f);
        float far = frame.value("far", 16.0f);

        Matrix4f camera_matrix = nrc::from_json(frame["transform_matrix"]);
        
        // TODO: per-camera dimensions
        cameras.emplace_back(near, far, focal_length, image_dimensions, sensor_size, camera_matrix);

        // images
        string file_path = frame["file_path"];
        path absolute_path = base_dir / file_path; // construct the absolute path using base_dir
        images.emplace_back(absolute_path.string(), image_dimensions);
    }

}

void Dataset::load_images_in_parallel(std::function<void(const size_t, const TrainingImage&)> post_load_image) {
    const size_t num_threads = std::thread::hardware_concurrency(); // get the number of available hardware threads

    std::vector<std::thread> threads;
    std::atomic<std::size_t> index{ 0 }; // atomic variable to track the next image to be loaded
    for (size_t i = 0; i < num_threads; ++i) {
        // create a new thread to load images
        threads.emplace_back([&] {
            std::size_t local_index;
            while ((local_index = index.fetch_add(1)) < images.size()) {
                images[local_index].load_cpu(n_channels_per_image);
                if (post_load_image) {
                    post_load_image(local_index, images[local_index]);
                }
            }
        });
    }

    // wait for all threads to complete
    for (auto& thread : threads) {
        thread.join();
    }
}
