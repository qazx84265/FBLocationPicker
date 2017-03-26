//
//  FBLocationPickerVC.m
//  FBLocationPicker
//
//  Created by FB on 2017/3/25.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "FBLocationPickerVC.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <Masonry/Masonry.h>
#import <MJRefresh/MJRefresh.h>

@interface FBLocationPickerVC ()<UITableViewDelegate, UITableViewDataSource, MAMapViewDelegate, AMapSearchDelegate> {
    int _page;
    int _limit;
}
@property (nonatomic, copy) pickerCallback pickerCallback;
@property (nonatomic, assign) pickerType pickerType;
@property (nonatomic, assign) BOOL isNeedLocation;

@property (nonatomic, strong) MAMapView* mapView;
@property (nonatomic, strong) UIButton* resetUserLocationBtn;
@property (nonatomic, strong) UIImageView* pinImgview;

@property (nonatomic, strong) AMapLocationManager* locationManager;
@property (nonatomic, strong) AMapSearchAPI* searchApi;

@property (nonatomic, strong) UITableView* poiTableView;
@property (nonatomic, strong) NSMutableArray* searchedPois;
@property (nonatomic, assign) NSInteger currentSelectLocationIndex;

@property (nonatomic, strong) UIActivityIndicatorView* indicatorView;
@end

@implementation FBLocationPickerVC

+ (void)showInViewController:(UIViewController *)viewController type:(pickerType)type pickerCallback:(pickerCallback)pickerCallback {
    FBLocationPickerVC* pickerVC = [[FBLocationPickerVC alloc] init];
    pickerVC.pickerType = type;
    pickerVC.pickerCallback = pickerCallback;
    if (viewController.navigationController) {
        [viewController.navigationController pushViewController:pickerVC animated:YES];
    }
    else {
        UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:pickerVC];
        [viewController presentViewController:nav animated:YES completion:nil];
    }
}

- (instancetype)init {
    if (self = [super init]) {
        self.pickerType = pickerType_done_with_sendButton;
        self.isNeedLocation = YES;
        self.currentSelectLocationIndex = 0;
        _page = 0;
        _limit = 10;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"选择位置";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
    // Do any additional setup after loading the view.
    
    [self setUI];
}

- (void)setUI {
    if (self.pickerType == pickerType_done_with_sendButton) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发送" style:UIBarButtonItemStylePlain target:self action:@selector(sendLocation:)];
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
    }
    
    [self.view addSubview:self.mapView];
    [self.view addSubview:self.resetUserLocationBtn];
    [self.view addSubview:self.pinImgview];
    [self.view addSubview:self.poiTableView];
    [self.poiTableView addSubview:self.indicatorView];
    [self.indicatorView startAnimating];
    
    //--
    [self setConstraints];
    
    UIView* v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 25)];
    v.backgroundColor = [UIColor lightGrayColor];
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, CGRectGetWidth(self.view.frame)-30, 25)];
    label.text = @"附近地址";
    label.font = [UIFont systemFontOfSize:12.0f];
    label.textColor = [UIColor darkTextColor];
    [v addSubview:label];
    self.poiTableView.tableHeaderView = v;
    
    __weak __typeof(self) weakSelf = self;
    MJRefreshAutoNormalFooter* footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        if (weakSelf.searchedPois.count>0) {
            _page += 1;
        }
        [weakSelf searchWithCoor:weakSelf.mapView.centerCoordinate];
    }];
    [footer setTitle:@"" forState:MJRefreshStateIdle];
    [footer setTitle:@"" forState:MJRefreshStatePulling];
    [footer setTitle:@"" forState:MJRefreshStateRefreshing];
    [footer setTitle:@"" forState:MJRefreshStateWillRefresh];
    _poiTableView.mj_footer  = footer;
    _poiTableView.mj_footer.hidden = YES;
    
}

- (void)setConstraints {
    __weak __typeof(self) weakSelf = self;
    
    [self.mapView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.equalTo(weakSelf.view);
        make.height.equalTo(weakSelf.view.mas_height).multipliedBy(0.5);
    }];
    
    CGFloat btnW = 41.0f;
    [self.resetUserLocationBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@(btnW));
        make.centerX.equalTo(weakSelf.view.mas_right).offset(-15-btnW/2.0);
        make.centerY.equalTo(weakSelf.mapView.mas_bottom).offset(-15-btnW/2.0);
    }];
    
    [self.pinImgview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@50);
        make.centerX.equalTo(weakSelf.mapView.mas_centerX);
        make.centerY.equalTo(weakSelf.mapView.mas_centerY).offset(-25);
    }];
    
    [self.poiTableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.equalTo(weakSelf.view);
        make.top.equalTo(weakSelf.mapView.mas_bottom);
    }];
    
    [self.indicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(weakSelf.view.mas_centerX);
        make.centerY.equalTo(weakSelf.view.mas_centerY).offset(35);
    }];
}

#pragma mark -- getters
- (MAMapView*)mapView {
    if (!_mapView) {
        _mapView = [[MAMapView alloc] init];
        _mapView.showsCompass = NO;
        _mapView.showsScale = NO;
        _mapView.showsUserLocation = YES;
        _mapView.mapType = MAMapTypeStandard;
        _mapView.userTrackingMode = MAUserTrackingModeFollow;
        _mapView.delegate = self;
    }
    return _mapView;
}

- (UIButton*)resetUserLocationBtn {
    if (!_resetUserLocationBtn) {
        _resetUserLocationBtn = [[UIButton alloc] init];
        [_resetUserLocationBtn setBackgroundColor:[UIColor redColor]];
        //[_resetUserLocationBtn setBackgroundImage:[UIImage imageNamed:@"pin.png"] forState:UIControlStateNormal];
        [_resetUserLocationBtn addTarget:self action:@selector(resetLocation:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _resetUserLocationBtn;
}

- (UIImageView*)pinImgview {
    if (!_pinImgview) {
        _pinImgview = [[UIImageView alloc] init];
        _pinImgview.backgroundColor = [UIColor clearColor];
        _pinImgview.image = [UIImage imageNamed:@"pin.png"];
    }
    return _pinImgview;
}

- (AMapLocationManager*)locationManager {
    if (!_locationManager) {
        _locationManager = [[AMapLocationManager alloc] init];
        _locationManager.locationTimeout = 5;
        _locationManager.reGeocodeTimeout = 5;
        //_locationManager.delegate = self;
    }
    return _locationManager;
}

- (AMapSearchAPI*)searchApi {
    if (!_searchApi) {
        _searchApi = [[AMapSearchAPI alloc] init];
        _searchApi.timeout = 5;
        _searchApi.delegate = self;
    }
    return _searchApi;
}

- (UITableView*)poiTableView {
    if (!_poiTableView) {
        _poiTableView = [[UITableView alloc] init];
        _poiTableView.delegate = self;
        _poiTableView.dataSource = self;
        _poiTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    }
    return _poiTableView;
}

- (UIActivityIndicatorView*)indicatorView {
    if (!_indicatorView) {
        _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    return _indicatorView;
}

- (NSMutableArray*)searchedPois {
    if (!_searchedPois) {
        _searchedPois = [NSMutableArray new];
    }
    return _searchedPois;
}



#pragma mark -- tableview delegate, data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchedPois.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}
- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* cellid = @"cellid";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellid];
    }
    
    AMapPOI* poi = [self.searchedPois objectAtIndex:indexPath.row];
    cell.textLabel.text = poi.name;
    cell.detailTextLabel.text = poi.address;
    
    if (self.pickerType == pickerType_done_with_sendButton) {
        cell.accessoryType = self.currentSelectLocationIndex==indexPath.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.searchedPois.count) {
        return;
    }
    
    if (self.pickerType == pickerType_done_with_select) {
        [self backWithPoiIndex:indexPath.row];
    }
    else {
        NSArray* paths = [tableView indexPathsForVisibleRows];
        for (NSIndexPath* path in paths) {
            if (path.row == self.currentSelectLocationIndex) {
                UITableViewCell* cell = [tableView cellForRowAtIndexPath:path];
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
            }
        }
        
        UITableViewCell* ccell = [tableView cellForRowAtIndexPath:indexPath];
        ccell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.currentSelectLocationIndex=indexPath.row;
    }
}
//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    CGFloat offset = scrollView.contentOffset.y;
//    __weak __typeof(self) weakSelf = self;
//    if (CGRectGetHeight(self.mapView.frame) > CGRectGetHeight(self.view.frame)*0.4) {
//        if (offset > 0) {
//            [self.mapView mas_remakeConstraints:^(MASConstraintMaker *make) {
//                make.left.top.right.equalTo(weakSelf.view);
//                make.height.equalTo(weakSelf.view.mas_height).multipliedBy(0.3);
//            }];
//            return;
//        }
//    }
//    else {
//        if (offset < 0) {
//            [self.mapView mas_remakeConstraints:^(MASConstraintMaker *make) {
//                make.left.top.right.equalTo(weakSelf.view);
//                make.height.equalTo(weakSelf.view.mas_height).multipliedBy(0.5);
//            }];
//            return;
//        }
//    }
//}



#pragma mark -- map view 
- (void)mapView:(MAMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"-------->>>>>>>>>>>  didFailToLocateUserWithError: %@", [error localizedDescription]);
}

- (void)mapViewDidStopLocatingUser:(MAMapView *)mapView {
    NSLog(@"-------->>>>>>>>>>>  mapViewDidStopLocatingUser");
}
- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation {
    //NSLog(@"-------->>>>>>>>>>>  didUpdateUserLocation");
    if (self.isNeedLocation) {
        [self searchWithCoor:userLocation.location.coordinate];
        
        self.isNeedLocation = NO;
    }
}
- (void)mapView:(MAMapView *)mapView mapDidMoveByUser:(BOOL)wasUserAction {
    if (!wasUserAction) {
        return;
    }
    NSLog(@"-------->>>>>>>>>>  mapDidMoveByUser");
    _page = 0;
    [self.searchedPois removeAllObjects];
    [self searchWithCoor:self.mapView.centerCoordinate];
}


- (void)searchWithCoor:(CLLocationCoordinate2D)coor {
    [self.searchApi cancelAllRequests];
    
    
    AMapPOIAroundSearchRequest* request = [[AMapPOIAroundSearchRequest alloc] init];
    request.location                    = [AMapGeoPoint locationWithLatitude:coor.latitude longitude:coor.longitude];
    request.keywords                    = @"";
    //request.sortrule                    = 0;
    request.requireExtension            = YES;
    request.radius                      = 1000;
    request.page                        = _page;
    request.offset                      = _limit;
    //request.types                       = @"050000|060000|070000|080000|090000|100000|110000|120000|130000|140000|150000|160000|170000";
    
    [self.searchApi AMapPOIAroundSearch:request];
}

#pragma mark -- search delegate
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response{
    if (!response
        ||!response.pois
        ||response.pois.count == 0){
        return;
    }
    
    [self.searchedPois addObjectsFromArray:response.pois];
    
    [self.poiTableView reloadData];
    
    [self.poiTableView.mj_footer endRefreshing];
    [self.indicatorView stopAnimating];
    
    self.poiTableView.mj_footer.hidden = self.searchedPois.count < _limit;
    [self.navigationItem.rightBarButtonItem setEnabled:self.searchedPois.count>0];
}


#pragma mark -- setters
- (void)setPickerType:(pickerType)pickerType {
    _pickerType = pickerType;
}

- (void)setPickerCallback:(pickerCallback)pickerCallback {
    if (pickerCallback) {
        _pickerCallback = [pickerCallback copy];
    }
}


#pragma mark -- actions
- (void)sendLocation:(id)sender {
    [self backWithPoiIndex:self.currentSelectLocationIndex];
}

- (void)resetLocation:(id)sender {
    [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
    _page = 0;
    [self.searchedPois removeAllObjects];
    [self searchWithCoor:self.mapView.centerCoordinate];
}

- (void)backWithPoiIndex:(NSInteger)index {
    AMapPOI* poi = [self.searchedPois objectAtIndex:index];
    if (self.pickerCallback) {
        self.pickerCallback(CLLocationCoordinate2DMake(poi.location.latitude, poi.location.longitude), poi.name);
    }
    
    [self back2LastUI];
}

- (void)back2LastUI {
    if (self.navigationController.viewControllers.count>1) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
