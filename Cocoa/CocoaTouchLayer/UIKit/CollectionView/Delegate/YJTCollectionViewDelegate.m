//
//  YJTCollectionViewDelegate.m
//  YJTCollectionView
//
//  HomePage:https://github.com/937447974/YJCocoa
//  YJ技术支持群:557445088
//
//  Created by 阳君 on 16/5/21.
//  Copyright © 2016年 YJCocoa. All rights reserved.
//

#import "YJTCollectionViewDelegate.h"
#import "YJTCollectionViewDataSource.h"
#import "YJSFoundationOther.h"
#import "UIView+YJTViewGeometry.h"

@interface YJTCollectionViewDelegate () {
    CGFloat _contentOffsetY; ///< scrollView.contentOffset.y
    CGFloat _contentOffsetYBegin; ///< 开始的点
    UICollectionViewFlowLayout *_flowLayout;
    NSMutableDictionary<NSString *, NSString*> *_cacheSizeDict; ///< 缓存Size
}

@property (nonatomic) YJTCollectionViewScroll scroll; ///< 滚动

@end

@implementation YJTCollectionViewDelegate

#pragma mark - init
- (instancetype)initWithDataSource:(YJTCollectionViewDataSource *)dataSource {
    self = [super init];
    if (self) {
        _dataSource = dataSource;
        _cacheSizeDict = [[NSMutableDictionary alloc] init];
        _isCacheSize = YES;
        _contentOffsetYBegin = CGFLOAT_MAX;
        self.scrollSpacingWill = 15;
        self.scrollSpacingDid = 30;
        if ([dataSource.collectionView.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
            _flowLayout = (UICollectionViewFlowLayout *)dataSource.collectionView.collectionViewLayout;
        }
    }
    return self;
}

#pragma mark - getter and setter
- (UICollectionViewFlowLayout *)flowLayout {
    if (!_flowLayout) {
        _flowLayout = [[UICollectionViewFlowLayout alloc] init];
        [self.dataSource.collectionView setCollectionViewLayout:_flowLayout animated:YES];// 动态替换
    }
    return _flowLayout;
}

- (void)setScroll:(YJTCollectionViewScroll)scroll {
    if (scroll != _scroll && [self.cellDelegate respondsToSelector:@selector(collectionView:scroll:)]) {
        _scroll = scroll;
        [self.cellDelegate collectionView:self.dataSource.collectionView scroll:scroll];
    }
}

#pragma mark - UICollectionViewCell向VC发送数据
- (void)sendVCWithCellObject:(YJTCollectionCellObject *)cellObject collectionViewCell:(UICollectionViewCell *)cell {
    if (self.cellBlock) { // block回调
        self.cellBlock(cellObject, cell);
    } else if ([self.cellDelegate respondsToSelector:@selector(collectionViewDidSelectCellWithCellObject:collectionViewCell:)]){
        [self.cellDelegate collectionViewDidSelectCellWithCellObject:cellObject collectionViewCell:cell];
    }
}

#pragma mark 清除所有缓存Size
- (void)clearAllCacheSize {
    [_cacheSizeDict removeAllObjects];
}

#pragma mark 获取cellObject对应的缓存key
- (NSString *)getKeyFromCellObject:(YJTCollectionCellObject *)cellObject {
    switch (self.cacheSizeStrategy) {
        case YJTCollectionViewCacheSizeDefault: // 根据相同的UITableViewCell类缓存高度
            return cellObject.cellName;
        case YJTCollectionViewCacheSizeIndexPath: // 根据NSIndexPath对应的位置缓存高度
            return [NSString stringWithFormat:@"%ld-%ld", cellObject.indexPath.section, cellObject.indexPath.item];
        case YJTCollectionViewCacheSizeClassAndIndexPath: // 根据类名和NSIndexPath双重绑定缓存高度
            return [NSString stringWithFormat:@"%@(%ld-%ld)", cellObject.cellName, cellObject.indexPath.section, cellObject.indexPath.item];
    }
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _contentOffsetY = scrollView.contentOffset.y;
    if (_contentOffsetYBegin == CGFLOAT_MAX) {
        _contentOffsetYBegin = _contentOffsetY;
    }
    self.scroll = YJTCollectionViewScrollNone;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat contentOffsetY = scrollView.contentOffset.y;
    CGFloat spacing = contentOffsetY - _contentOffsetY;
    if (contentOffsetY <= _contentOffsetYBegin) {
        self.scroll = YJTCollectionViewScrollEndTop;
    } else if (contentOffsetY + scrollView.heightFrame >= scrollView.contentSize.height) {
        self.scroll = YJTCollectionViewScrollEndBottom;
    } else if (spacing >= self.scrollSpacingDid ) {
        self.scroll = YJTCollectionViewScrollDidTop;
        _contentOffsetY = contentOffsetY;
    } else if (spacing >= self.scrollSpacingWill && self.scroll != YJTCollectionViewScrollDidTop) {
        self.scroll = YJTCollectionViewScrollWillTop;
    } else if (spacing <= -self.scrollSpacingDid ) {
        self.scroll = YJTCollectionViewScrollDidBottom;
        _contentOffsetY = contentOffsetY;
    } else if (spacing <= -self.scrollSpacingWill && self.scroll != YJTCollectionViewScrollDidBottom) {
        self.scroll = YJTCollectionViewScrollWillBottom;
    }    
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    YJTCollectionCellObject *cellObject = self.dataSource.dataSourceGrouped[indexPath.section][indexPath.item];
    [self sendVCWithCellObject:cellObject collectionViewCell:nil];
}

#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // 获取YJTableCellObject
    YJTCollectionCellObject *cellObject = self.dataSource.dataSourceGrouped[indexPath.section][indexPath.item];
    cellObject.indexPath = indexPath;
    // 存放缓存size的key
    NSString *key = [self getKeyFromCellObject:cellObject];
    CGSize size = self.flowLayout.itemSize;
    NSString *string;
    if (self.isCacheSize) {
        string = [_cacheSizeDict objectForKey:key];
    }
    if (!string) { //无缓存
        // 获取Size
        if ([cellObject.cellClass respondsToSelector:@selector(collectionViewDelegate:sizeForCellObject:)]) {
            size = [cellObject.cellClass collectionViewDelegate:self sizeForCellObject:cellObject];
        }
    } else {
        size = CGSizeFromString(string);
    }
    if (self.lineItems) {
        CGFloat itemW = (collectionView.frame.size.width - self.flowLayout.sectionInset.left - self.flowLayout.sectionInset.right - self.flowLayout.minimumInteritemSpacing * (self.lineItems - 1))/self.lineItems;
        if (self.itemHeightLayout) {
            size.height *= itemW / size.width;
        }
        size.width = itemW;
    }
    // 添加缓存
    if (self.isCacheSize) {
        [_cacheSizeDict setObject:NSStringFromCGSize(size) forKey:key];
    }
    return size;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return [self collectionView:collectionView viewForSupplementaryElementOfKind:UICollectionElementKindSectionHeader referenceSizeForFooterInSection:section];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return [self collectionView:collectionView viewForSupplementaryElementOfKind:UICollectionElementKindSectionFooter referenceSizeForFooterInSection:section];
}

- (CGSize)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind referenceSizeForFooterInSection:(NSInteger)section {
    YJTCollectionCellObject *cellObject;
    NSMutableArray<YJTCollectionCellObject *> *dataSource;
    if ([UICollectionElementKindSectionHeader isEqualToString:kind]) {
        dataSource = self.dataSource.headerDataSource;
    } else {
        dataSource = self.dataSource.footerDataSource;
    }
    CGSize size = CGSizeZero;
    if (dataSource.count == 0) {
        return size;
    }
    cellObject = dataSource[section];
    cellObject.indexPath = [NSIndexPath indexPathForItem:0 inSection:section];
    // 存放缓存size的key
    NSString *key = [NSString stringWithFormat:@"%@-%@", kind, [self getKeyFromCellObject:cellObject]];
    NSString *string;
    if (self.isCacheSize) {
        string = [_cacheSizeDict objectForKey:key];
    }
    if (!string) { //无缓存
        // 获取Size
        if ([cellObject.cellClass respondsToSelector:@selector(collectionViewDelegate:viewForSupplementaryElementOfKind:referenceSizeForCellObject:)]) {
            size = [cellObject.cellClass collectionViewDelegate:self viewForSupplementaryElementOfKind:kind referenceSizeForCellObject:cellObject];
        }
    } else {
        size = CGSizeFromString(string);
    }
    // 添加缓存
    if (self.isCacheSize) {
        [_cacheSizeDict setObject:NSStringFromCGSize(size) forKey:key];
    }
    return size;
}

@end