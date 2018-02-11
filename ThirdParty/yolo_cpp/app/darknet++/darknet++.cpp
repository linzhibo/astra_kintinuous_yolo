#include <fstream>

#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>

#include <yolo.h>

#include <iostream>
#include <algorithm>
#include <chrono>
#include <OpenNI.h>

using namespace std;
using namespace cv;
using namespace openni;

void showdevice();

Status initstream(Status& rc, Device& astra, VideoStream& streamDepth, VideoStream& streamColor);
Mat get_data_from_astra(char ColorOrDepth);


void showdevice()
{
  // get device information
  Array<DeviceInfo> aDeviceList;
  OpenNI::enumerateDevices(&aDeviceList);
  cout<< "Number of device(s) connected: "<< aDeviceList.getSize() <<endl;

  for (int i = 0; i< aDeviceList.getSize(); ++i)
  {
    cout <<"Device: "<< i << endl;
    const DeviceInfo& rDevInfo = aDeviceList[i];
    cout <<"Device name: "  << rDevInfo.getName()       <<endl;
    cout <<"Device Id: "  << rDevInfo.getUsbProductId()   <<endl;
    cout <<"Vendor name: "  << rDevInfo.getVendor()     <<endl;
    cout <<"Vendor Id:"   << rDevInfo.getUsbVendorId()  <<endl;
    cout <<"Device URI: " << rDevInfo.getUri()      <<endl;
  }
}

Status initstream(Status& rc, Device& astra, VideoStream& streamDepth, VideoStream& streamColor)
{
  rc = STATUS_OK;

  rc = streamDepth.create(astra, SENSOR_DEPTH);
  if(rc == STATUS_OK)
  {
    VideoMode mModeDepth;
    mModeDepth.setResolution(640, 480);
    mModeDepth.setFps(30);
    //mModeDepth.setPixelFormat(PIXEL_FORMAT_DEPTH_1_MM);
    mModeDepth.setPixelFormat(PIXEL_FORMAT_DEPTH_100_UM);

    streamDepth.setVideoMode(mModeDepth);
    streamDepth.setMirroringEnabled(false); 

    rc = streamDepth.start();
    if (rc != STATUS_OK)
    {
      cerr << "Can not read depth data: "<< OpenNI::getExtendedError() <<endl;
      streamDepth.destroy();
    }
  }

  else
  {
    cerr << "can not create depth data: "<< OpenNI::getExtendedError() <<endl;
  }

  rc = streamColor.create(astra, SENSOR_COLOR);
  if (rc == STATUS_OK)
  {
    VideoMode mModeColor;
    mModeColor.setResolution(640, 480);
    mModeColor.setFps(30);
    mModeColor.setPixelFormat(PIXEL_FORMAT_RGB888);

    streamColor.setVideoMode(mModeColor);
    streamColor.setMirroringEnabled(false);

    rc = streamColor.start();
    if (rc != STATUS_OK)
    {
      cerr << "can not open color data stream: "<< OpenNI::getExtendedError() <<endl;
      streamColor.destroy();
    }
  }
  else
  {
    cerr << "can not create color data: "<< OpenNI::getExtendedError() <<endl;
  }

  if  (!streamColor.isValid() || !streamDepth.isValid())
  {
    cerr << "color or depth data invalid" << endl;
    rc = STATUS_ERROR;
    return rc;
  }

  if (astra.isImageRegistrationModeSupported(IMAGE_REGISTRATION_DEPTH_TO_COLOR))
  {
    astra.setImageRegistrationMode(IMAGE_REGISTRATION_DEPTH_TO_COLOR);
  }

  return rc;
}

Mat get_data_from_astra(char ColorOrDepth)
{

  //cout << endl << ".........." << endl;
  // cout << "Openning Astra..." << endl;

  Status rc = STATUS_OK;
  OpenNI::initialize();
  //showdevice();
  Device astra;
  const char * deviceURL = openni::ANY_DEVICE;
  rc = astra.open(deviceURL);

  VideoStream streamColor;
  VideoStream streamDepth;

  if(initstream(rc, astra, streamDepth, streamColor) == STATUS_OK)
    cout << "Open Astra successfully!" << endl;
  else
  {
    cout << "Open Astra failed! " <<endl;
  }

  cv::Mat imRGB, imD;

  VideoFrameRef frameDepth;
  VideoFrameRef frameColor;

  if (ColorOrDepth == 'C')
  {
    rc = streamColor.readFrame(&frameColor);
    if(rc == STATUS_OK)
    {
      const Mat tImageRGB(frameColor.getHeight(), frameColor.getWidth(), CV_8UC3, (void*)frameColor.getData());
      cvtColor(tImageRGB, imRGB, CV_RGB2BGR);
    }
    return imRGB;
  }

  if (ColorOrDepth == 'D')
  {
    rc = streamDepth.readFrame(&frameDepth);
    if(rc == STATUS_OK)
    {
      imD = cv::Mat(frameDepth.getHeight(), frameDepth.getWidth(), CV_16UC1, (void*)frameDepth.getData());
    }
    return imD;
  }

}

void rotate_image_90n(cv::Mat &src, cv::Mat &dst, int angle)
{   
   if(src.data != dst.data){
       src.copyTo(dst);
   }

   angle = ((angle / 90) % 4) * 90;

   //0 : flip vertical; 1 flip horizontal
   bool const flip_horizontal_or_vertical = angle > 0 ? 1 : 0;
   int const number = std::abs(angle / 90);          

   for(int i = 0; i != number; ++i){
       cv::transpose(dst, dst);
       cv::flip(dst, dst, flip_horizontal_or_vertical);
   }
}

int main(int argc, char** argv)
{
    // if(argc < 2){
    //     fprintf(stderr, "usage: %s <videofile>\n", argv[0]);
    //     return 0;
    // }

    Yolo yolo;
    yolo.setConfigFilePath("cfg/yolo.cfg");
    yolo.setDataFilePath("cfg/coco.data");
    yolo.setWeightFilePath("yolo.weights");
    yolo.setAlphabetPath("data/labels/");
    yolo.setNameListFile("data/coco.names");
    yolo.setThreshold(0.3);

    // cv::VideoCapture capture(argv[1]);
    // if(!capture.isOpened())
    // {
    //     std::cout << "cannot read video file" << std::endl;
    //     return 0;
    // }

//    cv::Mat img = cv::imread("/home/yildirim/Dropbox/tayse/deep/1/images/img_3.png");
    Status rc = STATUS_OK;
    OpenNI::initialize();
    showdevice();
    Device astra;
    const char * deviceURL = openni::ANY_DEVICE;
    rc = astra.open(deviceURL);

    VideoStream streamColor;
    VideoStream streamDepth;

    if(initstream(rc, astra, streamDepth, streamColor) == STATUS_OK)
      cout << "Open Astra successfully!" << endl;
    else
    {
      cout << "Open Astra failed! " <<endl;
    }

    VideoFrameRef frameColor;
    cv::Mat img;
    bool continueornot = 1;
    while(continueornot)
    {
        //capture >> img;
      rc = streamColor.readFrame(&frameColor);
      if(rc == STATUS_OK)
      {
        const Mat tImageRGB(frameColor.getHeight(), frameColor.getWidth(), CV_8UC3, (void*)frameColor.getData());
        cvtColor(tImageRGB, img, CV_RGB2BGR);
      }
        if(img.empty())
            break;

	//rotate_image_90n(img, img, 90);

        cv::resize(img, img, cv::Size(412,412));

        std::vector<DetectedObject> detection;
        yolo.detect(img, detection);

        for(int i = 0; i < detection.size(); i++)
        {
            DetectedObject& o = detection[i];
            
            cv::rectangle(img, o.bounding_box, cv::Scalar(255,0,255), 2);

            const char* class_name = yolo.getNames()[o.object_class];

            char str[255];
            //sprintf(str,"%s %f", names[o.object_class], o.prob);
            sprintf(str,"%s", class_name);
            cv::putText(img, str, cv::Point2f(o.bounding_box.x,o.bounding_box.y), cv::FONT_HERSHEY_SIMPLEX, 0.6, cv::Scalar(0,0,240), 2);
          
        }
        cv::namedWindow("Astra detection demo", WINDOW_NORMAL);
        resizeWindow("Astra detection demo", 1000,600);

        cv::imshow("Astra detection demo", img);
        char c = cv::waitKey(5);
        switch(c)
        {
          case 'q':
          case 27:
            continueornot = false;
          break;
          case 'p':
            cv::waitKey(0);
            break;
          default:
            break;
        }

    }
    cv::destroyAllWindows();
    return 0;
}
