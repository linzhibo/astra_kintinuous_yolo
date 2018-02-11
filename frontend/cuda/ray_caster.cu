/*
 * This file is part of Kintinuous.
 *
 * Copyright (C) 2015 The National University of Ireland Maynooth and 
 * Massachusetts Institute of Technology
 *
 * The use of the code within this file and all code within files that 
 * make up the software that is Kintinuous is permitted for 
 * non-commercial purposes only.  The full terms and conditions that 
 * apply to the code within this file are detailed within the LICENSE.txt 
 * file and at <http://www.cs.nuim.ie/research/vision/data/kintinuous/code.php> 
 * unless explicitly stated.  By downloading this file you agree to 
 * comply with these terms.
 *
 * If you wish to use any of this code for commercial purposes then 
 * please email commercialisation@nuim.ie.
 *
 * Software License Agreement (BSD License)
 *
 *  Point Cloud Library (PCL) - www.pointclouds.org
 *  Copyright (c) 2011, Willow Garage, Inc.
 *
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above
 *     copyright notice, this list of conditions and the following
 *     disclaimer in the documentation and/or other materials provided
 *     with the distribution.
 *   * Neither the name of Willow Garage, Inc. nor the names of its
 *     contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "device.hpp"

__device__ __forceinline__ float
getMinTime (const float3& volume_max, const float3& origin, const float3& dir)
{
  float txmin = ( (dir.x > 0 ? 0.f : volume_max.x) - origin.x) / dir.x;
  float tymin = ( (dir.y > 0 ? 0.f : volume_max.y) - origin.y) / dir.y;
  float tzmin = ( (dir.z > 0 ? 0.f : volume_max.z) - origin.z) / dir.z;

  return fmax ( fmax (txmin, tymin), tzmin);
}

__device__ __forceinline__ float
getMaxTime (const float3& volume_max, const float3& origin, const float3& dir)
{
  float txmax = ( (dir.x > 0 ? volume_max.x : 0.f) - origin.x) / dir.x;
  float tymax = ( (dir.y > 0 ? volume_max.y : 0.f) - origin.y) / dir.y;
  float tzmax = ( (dir.z > 0 ? volume_max.z : 0.f) - origin.z) / dir.z;

  return fmin (fmin (txmax, tymax), tzmax);
}

struct RayCaster
{
  enum { CTA_SIZE_X = 32, CTA_SIZE_Y = 8 };

  Mat33 Rcurr;
  float3 tcurr;

  float time_step;
  float3 volume_size;

  float3 cell_size;
  int cols, rows;

  PtrStep<short> volume;

  Intr intr;

  mutable PtrStep<float> nmap;
  mutable PtrStep<float> vmap;

  int3 voxelWrap;

  mutable PtrStep<uchar4> vmap_curr_color;
  PtrStep<uchar4> color_volume;

  __device__ __forceinline__ float3
  get_ray_next (int x, int y) const
  {
    float3 ray_next;
    ray_next.x = (x - intr.cx) / intr.fx;
    ray_next.y = (y - intr.cy) / intr.fy;
    ray_next.z = 1;
    return ray_next;
  }

  __device__ __forceinline__ bool
  checkInds (const int3& g) const
  {
    return (g.x >= 0 && g.y >= 0 && g.z >= 0 && g.x < VOLUME_X && g.y < VOLUME_Y && g.z < VOLUME_X);
  }

  __device__ __forceinline__ float
  readTsdf (int x, int y, int z) const
  {
      const short * pos = &volume.ptr(0)[((x + voxelWrap.x) % VOLUME_X) + ((y + voxelWrap.y) % VOLUME_Y) * VOLUME_X + ((z + voxelWrap.z) % VOLUME_Z) * VOLUME_X * VOLUME_Y];
      return unpack_tsdf (*pos);
  }

  __device__ __forceinline__ float
  readHeat (int x, int y, int z) const
  {
      const uchar4 * ptrColor = &color_volume.ptr(0)[((x + voxelWrap.x) % VOLUME_X) + ((y + voxelWrap.y) % VOLUME_Y) * VOLUME_X + ((z + voxelWrap.z) % VOLUME_Z) * VOLUME_X * VOLUME_Y];
      return ptrColor->w;
  }

  __device__ __forceinline__ float
  readRed (int x, int y, int z) const
  {
      const uchar4 * ptrColor = &color_volume.ptr(0)[((x + voxelWrap.x) % VOLUME_X) + ((y + voxelWrap.y) % VOLUME_Y) * VOLUME_X + ((z + voxelWrap.z) % VOLUME_Z) * VOLUME_X * VOLUME_Y];
      return ptrColor->x;
  }

  __device__ __forceinline__ float
  readGreen (int x, int y, int z) const
  {
      const uchar4 * ptrColor = &color_volume.ptr(0)[((x + voxelWrap.x) % VOLUME_X) + ((y + voxelWrap.y) % VOLUME_Y) * VOLUME_X + ((z + voxelWrap.z) % VOLUME_Z) * VOLUME_X * VOLUME_Y];
      return ptrColor->y;
  }

  __device__ __forceinline__ float
  readBlue (int x, int y, int z) const
  {
      const uchar4 * ptrColor = &color_volume.ptr(0)[((x + voxelWrap.x) % VOLUME_X) + ((y + voxelWrap.y) % VOLUME_Y) * VOLUME_X + ((z + voxelWrap.z) % VOLUME_Z) * VOLUME_X * VOLUME_Y];
      return ptrColor->z;
  }

  __device__ __forceinline__ int3
  getVoxel (float3 point) const
  {
    int vx = __float2int_rd (point.x / cell_size.x);        // round to negative infinity
    int vy = __float2int_rd (point.y / cell_size.y);
    int vz = __float2int_rd (point.z / cell_size.z);

    return make_int3 (vx, vy, vz);
  }

  __device__ __forceinline__ float
  interpolateTrilineary (const float3& origin, const float3& dir, float time) const
  {
    return interpolateTrilineary (origin + dir * time);
  }

  __device__ __forceinline__ float
  interpolateTrilineary (const float3& point) const
  {
    int3 g = getVoxel (point);

    if (g.x <= 0 || g.x >= VOLUME_X - 1)
      return numeric_limits<float>::quiet_NaN ();

    if (g.y <= 0 || g.y >= VOLUME_Y - 1)
      return numeric_limits<float>::quiet_NaN ();

    if (g.z <= 0 || g.z >= VOLUME_Z - 1)
      return numeric_limits<float>::quiet_NaN ();

    float vx = (g.x + 0.5f) * cell_size.x;
    float vy = (g.y + 0.5f) * cell_size.y;
    float vz = (g.z + 0.5f) * cell_size.z;

    g.x = (point.x < vx) ? (g.x - 1) : g.x;
    g.y = (point.y < vy) ? (g.y - 1) : g.y;
    g.z = (point.z < vz) ? (g.z - 1) : g.z;

    float a = (point.x - (g.x + 0.5f) * cell_size.x) / cell_size.x;
    float b = (point.y - (g.y + 0.5f) * cell_size.y) / cell_size.y;
    float c = (point.z - (g.z + 0.5f) * cell_size.z) / cell_size.z;

    float res = readTsdf (g.x + 0, g.y + 0, g.z + 0) * (1 - a) * (1 - b) * (1 - c) +
                readTsdf (g.x + 0, g.y + 0, g.z + 1) * (1 - a) * (1 - b) * c +
                readTsdf (g.x + 0, g.y + 1, g.z + 0) * (1 - a) * b * (1 - c) +
                readTsdf (g.x + 0, g.y + 1, g.z + 1) * (1 - a) * b * c +
                readTsdf (g.x + 1, g.y + 0, g.z + 0) * a * (1 - b) * (1 - c) +
                readTsdf (g.x + 1, g.y + 0, g.z + 1) * a * (1 - b) * c +
                readTsdf (g.x + 1, g.y + 1, g.z + 0) * a * b * (1 - c) +
                readTsdf (g.x + 1, g.y + 1, g.z + 1) * a * b * c;
    return res;
  }

  __device__ __forceinline__ uchar3
  interpolateColorTrilineary (const float3& point) const
  {
    int3 g = getVoxel (point);

    uchar3 black = {0, 0, 0};

    if (g.x <= 0 || g.x >= VOLUME_X - 1)
      return black;

    if (g.y <= 0 || g.y >= VOLUME_Y - 1)
      return black;

    if (g.z <= 0 || g.z >= VOLUME_Z - 1)
      return black;

    float vx = (g.x + 0.5f) * cell_size.x;
    float vy = (g.y + 0.5f) * cell_size.y;
    float vz = (g.z + 0.5f) * cell_size.z;

    g.x = (point.x < vx) ? (g.x - 1) : g.x;
    g.y = (point.y < vy) ? (g.y - 1) : g.y;
    g.z = (point.z < vz) ? (g.z - 1) : g.z;

    float a = (point.x - (g.x + 0.5f) * cell_size.x) / cell_size.x;
    float b = (point.y - (g.y + 0.5f) * cell_size.y) / cell_size.y;
    float c = (point.z - (g.z + 0.5f) * cell_size.z) / cell_size.z;

    uchar3 res = {readRed (g.x + 0, g.y + 0, g.z + 0) * (1 - a) * (1 - b) * (1 - c) +
                  readRed (g.x + 0, g.y + 0, g.z + 1) * (1 - a) * (1 - b) * c +
                  readRed (g.x + 0, g.y + 1, g.z + 0) * (1 - a) * b * (1 - c) +
                  readRed (g.x + 0, g.y + 1, g.z + 1) * (1 - a) * b * c +
                  readRed (g.x + 1, g.y + 0, g.z + 0) * a * (1 - b) * (1 - c) +
                  readRed (g.x + 1, g.y + 0, g.z + 1) * a * (1 - b) * c +
                  readRed (g.x + 1, g.y + 1, g.z + 0) * a * b * (1 - c) +
                  readRed (g.x + 1, g.y + 1, g.z + 1) * a * b * c,
                  readGreen (g.x + 0, g.y + 0, g.z + 0) * (1 - a) * (1 - b) * (1 - c) +
                  readGreen (g.x + 0, g.y + 0, g.z + 1) * (1 - a) * (1 - b) * c +
                  readGreen (g.x + 0, g.y + 1, g.z + 0) * (1 - a) * b * (1 - c) +
                  readGreen (g.x + 0, g.y + 1, g.z + 1) * (1 - a) * b * c +
                  readGreen (g.x + 1, g.y + 0, g.z + 0) * a * (1 - b) * (1 - c) +
                  readGreen (g.x + 1, g.y + 0, g.z + 1) * a * (1 - b) * c +
                  readGreen (g.x + 1, g.y + 1, g.z + 0) * a * b * (1 - c) +
                  readGreen (g.x + 1, g.y + 1, g.z + 1) * a * b * c,
                  readBlue (g.x + 0, g.y + 0, g.z + 0) * (1 - a) * (1 - b) * (1 - c) +
                  readBlue (g.x + 0, g.y + 0, g.z + 1) * (1 - a) * (1 - b) * c +
                  readBlue (g.x + 0, g.y + 1, g.z + 0) * (1 - a) * b * (1 - c) +
                  readBlue (g.x + 0, g.y + 1, g.z + 1) * (1 - a) * b * c +
                  readBlue (g.x + 1, g.y + 0, g.z + 0) * a * (1 - b) * (1 - c) +
                  readBlue (g.x + 1, g.y + 0, g.z + 1) * a * (1 - b) * c +
                  readBlue (g.x + 1, g.y + 1, g.z + 0) * a * b * (1 - c) +
                  readBlue (g.x + 1, g.y + 1, g.z + 1) * a * b * c};

    return res;
  }

  __device__ __forceinline__ float
  interpolateHeatTrilineary (const float3& point) const
  {
    int3 g = getVoxel (point);

    if (g.x <= 0 || g.x >= VOLUME_X - 1)
      return numeric_limits<float>::quiet_NaN ();

    if (g.y <= 0 || g.y >= VOLUME_Y - 1)
      return numeric_limits<float>::quiet_NaN ();

    if (g.z <= 0 || g.z >= VOLUME_Z - 1)
      return numeric_limits<float>::quiet_NaN ();

    float vx = (g.x + 0.5f) * cell_size.x;
    float vy = (g.y + 0.5f) * cell_size.y;
    float vz = (g.z + 0.5f) * cell_size.z;

    g.x = (point.x < vx) ? (g.x - 1) : g.x;
    g.y = (point.y < vy) ? (g.y - 1) : g.y;
    g.z = (point.z < vz) ? (g.z - 1) : g.z;

    float a = (point.x - (g.x + 0.5f) * cell_size.x) / cell_size.x;
    float b = (point.y - (g.y + 0.5f) * cell_size.y) / cell_size.y;
    float c = (point.z - (g.z + 0.5f) * cell_size.z) / cell_size.z;

    float res = readHeat (g.x + 0, g.y + 0, g.z + 0) * (1 - a) * (1 - b) * (1 - c) +
                readHeat (g.x + 0, g.y + 0, g.z + 1) * (1 - a) * (1 - b) * c +
                readHeat (g.x + 0, g.y + 1, g.z + 0) * (1 - a) * b * (1 - c) +
                readHeat (g.x + 0, g.y + 1, g.z + 1) * (1 - a) * b * c +
                readHeat (g.x + 1, g.y + 0, g.z + 0) * a * (1 - b) * (1 - c) +
                readHeat (g.x + 1, g.y + 0, g.z + 1) * a * (1 - b) * c +
                readHeat (g.x + 1, g.y + 1, g.z + 0) * a * b * (1 - c) +
                readHeat (g.x + 1, g.y + 1, g.z + 1) * a * b * c;
    return res;
  }

  __device__ __forceinline__ void
  operator () () const
  {
    int x = threadIdx.x + blockIdx.x * CTA_SIZE_X;
    int y = threadIdx.y + blockIdx.y * CTA_SIZE_Y;

    if (x >= cols || y >= rows)
      return;

    vmap.ptr (y)[x] = numeric_limits<float>::quiet_NaN ();
    nmap.ptr (y)[x] = numeric_limits<float>::quiet_NaN ();

    float3 ray_start = tcurr;
    float3 ray_next = Rcurr * get_ray_next (x, y) + tcurr;

    float3 ray_dir = normalized (ray_next - ray_start);

    //ensure that it isn't a degenerate case
    ray_dir.x = (ray_dir.x == 0.f) ? 1e-15 : ray_dir.x;
    ray_dir.y = (ray_dir.y == 0.f) ? 1e-15 : ray_dir.y;
    ray_dir.z = (ray_dir.z == 0.f) ? 1e-15 : ray_dir.z;

    // computer time when entry and exit volume
    float time_start_volume = getMinTime (volume_size, ray_start, ray_dir);
    float time_exit_volume = getMaxTime (volume_size, ray_start, ray_dir);

    const float min_dist = 0.f;         //in meters
    time_start_volume = fmax (time_start_volume, min_dist);
    if (time_start_volume >= time_exit_volume)
      return;

    float time_curr = time_start_volume;
    int3 g = getVoxel (ray_start + ray_dir * time_curr);
    g.x = max (0, min (g.x, VOLUME_X - 1));
    g.y = max (0, min (g.y, VOLUME_Y - 1));
    g.z = max (0, min (g.z, VOLUME_Z - 1));

    float tsdf = readTsdf (g.x, g.y, g.z);

    //infinite loop guard
    const float max_time = 3 * (volume_size.x + volume_size.y + volume_size.z);

    for (; time_curr < max_time; time_curr += time_step)
    {
      float tsdf_prev = tsdf;

      int3 g = getVoxel (  ray_start + ray_dir * (time_curr + time_step)  );
      if (!checkInds (g))
        break;

      tsdf = readTsdf (g.x, g.y, g.z);

      if (tsdf_prev < 0.f && tsdf > 0.f)
        break;

      if (tsdf_prev > 0.f && tsdf < 0.f)           //zero crossing
      {
        float Ftdt = interpolateTrilineary (ray_start, ray_dir, time_curr + time_step);
        if (isnan (Ftdt))
          break;

        float Ft = interpolateTrilineary (ray_start, ray_dir, time_curr);
        if (isnan (Ft))
          break;

        float Ts = time_curr - time_step * Ft / (Ftdt - Ft);

        float3 vetex_found = ray_start + ray_dir * Ts;

        vmap.ptr (y       )[x] = vetex_found.x;
        vmap.ptr (y + rows)[x] = vetex_found.y;
        vmap.ptr (y + 2 * rows)[x] = vetex_found.z;

        int3 g = getVoxel ( ray_start + ray_dir * time_curr );

        uchar3 pointColor = interpolateColorTrilineary(vetex_found);

        vmap_curr_color.ptr(y)[x].x = pointColor.x;
        vmap_curr_color.ptr(y)[x].y = pointColor.y;
        vmap_curr_color.ptr(y)[x].z = pointColor.z;
        vmap_curr_color.ptr(y)[x].w = interpolateHeatTrilineary(vetex_found);

        if (g.x > 1 && g.y > 1 && g.z > 1 && g.x < VOLUME_X - 2 && g.y < VOLUME_Y - 2 && g.z < VOLUME_Z - 2)
        {
          float3 t;
          float3 n;

          t = vetex_found;
          t.x += cell_size.x;
          float Fx1 = interpolateTrilineary (t);

          t = vetex_found;
          t.x -= cell_size.x;
          float Fx2 = interpolateTrilineary (t);

          n.x = (Fx1 - Fx2);

          t = vetex_found;
          t.y += cell_size.y;
          float Fy1 = interpolateTrilineary (t);

          t = vetex_found;
          t.y -= cell_size.y;
          float Fy2 = interpolateTrilineary (t);

          n.y = (Fy1 - Fy2);

          t = vetex_found;
          t.z += cell_size.z;
          float Fz1 = interpolateTrilineary (t);

          t = vetex_found;
          t.z -= cell_size.z;
          float Fz2 = interpolateTrilineary (t);

          n.z = (Fz1 - Fz2);

          n = normalized (n);

          nmap.ptr (y       )[x] = n.x;
          nmap.ptr (y + rows)[x] = n.y;
          nmap.ptr (y + 2 * rows)[x] = n.z;
        }
        break;
      }

    }          /* for(;;)  */
  }
};

__global__ void
rayCastKernel (const RayCaster rc) {
  rc ();
}

void
raycast (const Intr& intr, const Mat33& Rcurr, const float3& tcurr, 
                      float tranc_dist, const float3& volume_size,
                      const PtrStep<short>& volume, DeviceArray2D<float>& vmap, DeviceArray2D<float>& nmap, const int3 & voxelWrap, DeviceArray2D<uchar4> & vmap_curr_color,
                      PtrStep<uchar4> color_volume)
{
  RayCaster rc;

  rc.Rcurr = Rcurr;
  rc.tcurr = tcurr;

  rc.time_step = tranc_dist * 0.8f;

  rc.volume_size = volume_size;

  rc.cell_size.x = volume_size.x / VOLUME_X;
  rc.cell_size.y = volume_size.y / VOLUME_Y;
  rc.cell_size.z = volume_size.z / VOLUME_Z;

  rc.cols = vmap.cols ();
  rc.rows = vmap.rows () / 3;

  rc.intr = intr;

  rc.volume = volume;
  rc.vmap = vmap;
  rc.nmap = nmap;

  rc.voxelWrap = voxelWrap;

  rc.vmap_curr_color = vmap_curr_color;
  rc.color_volume = color_volume;

  dim3 block (RayCaster::CTA_SIZE_X, RayCaster::CTA_SIZE_Y);
  dim3 grid (divUp (rc.cols, block.x), divUp (rc.rows, block.y));

  rayCastKernel<<<grid, block>>>(rc);
  cudaSafeCall (cudaGetLastError ());
}

