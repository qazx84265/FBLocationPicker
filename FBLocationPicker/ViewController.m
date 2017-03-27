//
//  ViewController.m
//  FBLocationPicker
//
//  Created by FB on 2017/3/25.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "ViewController.h"
#import "FBLocationPickerVC.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *latLabel;
@property (weak, nonatomic) IBOutlet UILabel *lngLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;


- (IBAction)getLocation:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Demo";
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)getLocation:(id)sender {
    
    __weak __typeof(self) weakSelf = self;
    [FBLocationPickerVC showInViewController:self type:pickerType_done_with_sendButton pickerCallback:^(CLLocationCoordinate2D coor, NSString *formatLocation) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return ;
        }
        
        if (CLLocationCoordinate2DIsValid(coor)) {
            strongSelf.latLabel.text = [NSString stringWithFormat:@"lat: %.6f", coor.latitude];
            strongSelf.lngLabel.text = [NSString stringWithFormat:@"lng: %.6f", coor.longitude];
        }
        if (formatLocation) {
            strongSelf.locationLabel.text = formatLocation;
        }
    }];
}
@end
