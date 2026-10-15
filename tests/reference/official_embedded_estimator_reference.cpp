#include "mex.h"
#include "MadgwickAHRS.h"
#include "alt_kalman.hpp"
#include <cstdint>
#define PI 3.1415926535897932384626433832795
void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]) {
  if(nrhs!=1 || !mxIsSingle(prhs[0]) || mxGetN(prhs[0])!=12)
    mexErrMsgIdAndTxt("official:estimator:input","Expected single N x 12");
  mwSize n=mxGetM(prhs[0]); const float* u=mxGetSingles(prhs[0]);
  plhs[0]=mxCreateNumericMatrix(n,6,mxSINGLE_CLASS,mxREAL);float* out=mxGetSingles(plhs[0]);
  Madgwick ahrs;ahrs.begin(400);Alt_kalman kalman;bool first=true;
  for(mwSize i=0;i<n;++i) {
    if(u[i+n*10]!=0) ahrs.reset();
    ahrs.updateIMU(u[i+n*1]*(float)(180/PI),u[i+n*0]*(float)(180/PI),-u[i+n*2]*(float)(180/PI),
      u[i+n*4],u[i+n*3],-u[i+n*5]);
    if(u[i+n*11]!=0)kalman.reset();if(first)first=false;else kalman.update(u[i+n*6],u[i+n*7],u[i+n*8]);
    float row[6]={ahrs.getPitch()*(float)(PI/180),ahrs.getRoll()*(float)(PI/180),
      -ahrs.getYaw()*(float)(PI/180),kalman.Velocity,kalman.Altitude,kalman.Bias};
    for(int j=0;j<6;++j)out[i+n*j]=row[j];
  }
}
