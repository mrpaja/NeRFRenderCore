#pragma once

#include <tiny-cuda-nn/common.h>

#include "../common.h"
#include "../core/occupancy-grid.cuh"
#include "../models/bounding-box.cuh"
#include "../models/camera.cuh"
#include "workspace.cuh"

NRC_NAMESPACE_BEGIN

struct RenderingWorkspace: Workspace {

    using Workspace::Workspace;

	uint32_t batch_size;
	
	// misc
	Camera* camera;
	BoundingBox* bounding_box;
	OccupancyGrid* occupancy_grid;

	// compaction
	int* compact_idx;

	// rays
	bool* ray_alive;
	bool* ray_active[2];
	float* ray_origin[2];
	float* ray_dir[2];
	float* ray_idir[2];
	float* ray_t[2];
	float* ray_trans[2]; // accumulated sigma
	uint32_t* ray_steps[2];

	// 2D ray index (x + y * width)
	uint32_t* ray_idx[2]; 
	
	// samples
	float* network_pos;
	float* network_dir;
	float* network_dt;
	float* sample_alpha;

	// network buffers
	tcnn::network_precision_t* network_concat;
	tcnn::network_precision_t* network_output;

	// output buffers
	float* rgba;
	uint32_t n_pixels = 0;

	// samples
	void enlarge(
		const cudaStream_t& stream,
		const uint32_t& n_pixels,
		const uint32_t& n_elements_per_batch,
		const uint32_t& n_network_concat_elements,
		const uint32_t& n_network_output_elements
	) {
		free_allocations();

		batch_size = tcnn::next_multiple(n_elements_per_batch, tcnn::batch_size_granularity);
		uint32_t n_output_pixel_elements = tcnn::next_multiple(4 * n_pixels, tcnn::batch_size_granularity);

		// camera
		camera			= allocate<Camera>(stream, 1);
		bounding_box	= allocate<BoundingBox>(stream, 1);
		occupancy_grid	= allocate<OccupancyGrid>(stream, 1);

		// compaction
		compact_idx		= allocate<int>(stream, batch_size);

		// rays
		ray_alive		= allocate<bool>(stream, batch_size); // no need to double buffer

		// double buffers
		ray_active[0]	= allocate<bool>(stream, batch_size);
		ray_active[1]	= allocate<bool>(stream, batch_size);

		ray_origin[0]	= allocate<float>(stream, 3 * batch_size);
		ray_origin[1]	= allocate<float>(stream, 3 * batch_size);
		
		ray_dir[0]		= allocate<float>(stream, 3 * batch_size);
		ray_dir[1]		= allocate<float>(stream, 3 * batch_size);

		ray_idir[0]		= allocate<float>(stream, 3 * batch_size);
		ray_idir[1]		= allocate<float>(stream, 3 * batch_size);

		ray_t[0]		= allocate<float>(stream, batch_size);
		ray_t[1]		= allocate<float>(stream, batch_size);

		ray_idx[0]		= allocate<uint32_t>(stream, batch_size);
		ray_idx[1]		= allocate<uint32_t>(stream, batch_size);

		ray_trans[0]	= allocate<float>(stream, batch_size);
		ray_trans[1]	= allocate<float>(stream, batch_size);

		ray_steps[0]	= allocate<uint32_t>(stream, batch_size);
		ray_steps[1]	= allocate<uint32_t>(stream, batch_size);

		// samples
		network_pos		= allocate<float>(stream, 3 * batch_size);
		network_dir		= allocate<float>(stream, 3 * batch_size);
		network_dt		= allocate<float>(stream, batch_size);
		sample_alpha	= allocate<float>(stream, batch_size);

		// network
		network_concat	= allocate<tcnn::network_precision_t>(stream, n_network_concat_elements * batch_size);
		network_output	= allocate<tcnn::network_precision_t>(stream, n_network_output_elements * batch_size);

		// output
		rgba			= allocate<float>(stream, n_output_pixel_elements);

		this->n_pixels = n_pixels;
	};
};

NRC_NAMESPACE_END