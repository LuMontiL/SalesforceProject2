import { LightningElement, api } from 'lwc';
import {NavigationMixin} from 'lightning/navigation';

export default class NavigateToModule extends NavigationMixin(LightningElement) {

    @api recordId;

    handleNavigate(){
        const recordId = this.recordId;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }



}